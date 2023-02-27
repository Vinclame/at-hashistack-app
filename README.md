# at-hashistack-app

## NFS configuration

```bash
sudo -i
mkdir /storage
echo "/storage     *(rw,sync,no_root_squash,no_subtree_check)" > /etc/exports
systemctl restart nfs-server
exit
```

## Vault

Add policy and 2 secrets key

```bash
cd ~/at-hashistack-app/vault
./vault.sh
```

## Nomad

cd ~/at-hashistack-app/nomad

### Source environment vars

```bash
export NOMAD_ADDR="https://nomad.service.inthepicture.photo:4646"
echo "!!" > nomad.env
export NOMAD_TOKEN=$(grep 'Secret ID' ~/bootstrap-tokens/management.nomad.token | awk -F'= ' {'print $2'})
echo "!!" >> nomad.env
source nomad.env
```

### Install CSI

```bash
nomad run controller.nomad
nomad run node.nomad
nomad plugin status # 1 controller and 3 nodes running
nomad volume create mysql.volume
nomad volume create http.volume # http server has to be stateful because images are stored here
nomad volume status # Access mode still empty, thats okay
ls /storage # 2 directories: mysql and http 
```

### Install Nomad jobs

```bash
nomad run mysql.nomad
nomad run httpd.nomad 
nomad run nginx.nomad
```

## Check services in Consul

## Verify web app
http://web.service.inthepicture.photo
