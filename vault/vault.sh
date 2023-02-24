#!/bin/bash

### VAULT

function vault_checks() {
  # Retrieve bootstrap location from roles var file
  BOOT_LOC=$(grep bootstrap_location ~/at-hashistack/roles/common/vars/main.yml | cut -d/ -f4 | tr -d '"')

  # Token directory
  TOKENS_DIR="$HOME/$BOOT_LOC"

  VAULT_USER="atcomputing"
  VAULT_PASSWORD="$(cat $TOKENS_DIR/atcomputing.vault.password 2>/dev/null)"
  VAULT_USERPASS_STAT=$(echo $?)

  MYSQL_ROOT_PASSWD=$(uuidgen)
  MYSQL_GURU_PASSWD=$(uuidgen)

  VAULT_SERVERS_GROUP=$(ansible-inventory --inventory-file ~/at-hashistack/inventory --list | jq -r ".vault_servers.hosts | .[]" 2>/dev/null)
  VAULT_SERVERS_GROUP_STATE=$(echo $?)

  KV_PATH="kv"

  if [ $VAULT_SERVERS_GROUP_STATE ]; then
    STAT="DONE"
  else
    STAT="FAILED"
  fi

  declare -a VAULT_SERVERS=($(echo $VAULT_SERVERS_GROUP))

  export VAULT_ADDR="https://${VAULT_SERVERS[0]}:$VAULT_PORT"

  ### Vault initialization state
  echo ""
  for V in "${VAULT_SERVERS[@]}"
  do
    VAULT_INIT=$(curl -k -s -H "X-Vault-Token: $VAULT_TOKEN" https://${V}:$VAULT_PORT/v1/sys/health | jq -r .initialized)
    if [ "$VAULT_INIT" == "true" ]; then
      STAT="TRUE"
    else
      STAT="FALSE"
    fi
    echo "Checking if Vault is initialized on $V (API GET /sys/health)" $STAT
  done

  ### Vault sealed state
  echo ""
  for V in "${VAULT_SERVERS[@]}"
  do
    VAULT_SEAL=$(curl -k -s -H "X-Vault-Token: $VAULT_TOKEN" https://${V}:$VAULT_PORT/v1/sys/health | jq -r .sealed)
    if [ "$VAULT_SEAL" == "false" ]; then
      STAT="TRUE"
    else
      STAT="FALSE"
    fi
    echo "Checking if Vault is unsealed on $V (API GET /sys/health)" $STAT
  done

  ### Vault login with atcomputing user
  echo ""
  VAULT_LOGIN=$(curl -f -k -s --request POST --data "{\"password\": \"$VAULT_PASSWORD\"}" https://${VAULT_SERVERS[0]}:8200/v1/auth/userpass/login/$VAULT_USER) # | jq -r .auth.client_token)
  VAULT_LOGIN_STAT=$(echo $?)
  if [ $VAULT_LOGIN_STAT -eq 0 ]; then
    VAULT_TOKEN=$(echo $VAULT_LOGIN | jq -r .auth.client_token)
    STAT="SUCCEEDED"
    VSUC=1
  else
    VAULT_TOKEN="INVALID"
    STAT="FAILED"
    VSUC=0
  fi
  echo "Log in with $VAULT_USER user (API POST /auth/userpass/login/$VAULT_USER)" $STAT

  ### Vault create KV/2 engine
  if [ $VSUC -eq 1 ]; then
    VAULT_KV=$(curl -f -k -s --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data "{\"type\": \"kv-v2\"}" https://${VAULT_SERVERS[0]}:8200/v1/sys/mounts/kv 2>/dev/null ; echo $?)
    if [ $VAULT_KV -eq 0 ]; then
      STAT="SUCCEEDED"
    else
      STAT="FAILED"
    fi
  else
    STAT="SKIPPED"
  fi
  echo "Mounting kv-v2 secrets engine 'shutter' (API POST /sys/mounts/kv)" $STAT

  ### Vault create secrets
  if [ $VSUC -eq 1 ]; then
    VAULT_CREATE_SECRET=$(curl -f -k -s --header "X-Vault-Token: $VAULT_TOKEN" --request POST \
    --data "{ \
     \"options\": { \"cas\": 0 }, \
     \"data\": { \
       \"MYSQL_ROOT_PASSWORD\": \"${MYSQL_ROOT_PASSWD}\", \
       \"MYSQL_GURU_PASSWORD\": \"${MYSQL_GURU_PASSWD}\" } }" \
    https://${VAULT_SERVERS[0]}:8200/v1/kv/data/mysql 2>/dev/null)
    VAULT_CREATE_SECRET_STATUS=$(echo $?)
    if [ $VAULT_CREATE_SECRET_STATUS -eq 0 ]; then
      STAT="SUCCEEDED"
    else
      STAT="FAILED"
    fi
  else
    STAT="SKIPPED"
  fi
  echo "Creating secrets 'MYSQL_ROOT_PASSWORD' and 'MYSQL_GURU_PASSWORD' in 'kv' kv-v2 secrets engine (API POST /kv/data/mysql)" $STAT

  ### Vault read secret
  if [ $VSUC -eq 1 ]; then
    VAULT_READ_SECRET=$(curl -f -k -s --header "X-Vault-Token: $VAULT_TOKEN" https://${VAULT_SERVERS[0]}:8200/v1/kv/data/mysql 2>/dev/null | jq -jc .data.data | tr -d '{}')
    if [ "$VAULT_READ_SECRET" != ""  ]; then
      STAT=$VAULT_READ_SECRET
    else
      STAT="FAILED"
    fi
  else
    STAT="SKIPPED"
  fi
  echo "Reading secret 'mysql' from 'kv' kv-v2 secrets engine (API GET /kv/data/mysql)" $STAT
  echo ""

  if [ $VSUC -eq 1 ]; then
    VAULT_CREATE_POLICY=$(curl -f -k -s --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data @payload.json \
	https://${VAULT_SERVERS[0]}:8200/v1/sys/policy/mysql-access 2>/dev/null)
    VAULT_CREATE_POLICY_STATUS=$(echo $?)
    if [ $VAULT_CREATE_POLICY_STATUS -eq 0 ]; then
      STAT="SUCCEEDED"
    else
      STAT="FAILED"
    fi
  else
    STAT="SKIPPED"
  fi
  echo "Creating policy 'mysql-access' (API POST /sys/policy/mysql-access)" $STAT
}

vault_checks
