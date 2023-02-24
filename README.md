# at-hashistack-demo
`sudo mkdir /storage`
`sudo echo "/storage     *(rw,sync,no_root_squash,no_subtree_check)" > /etc/exports`
`sudo systemctl restart nfs-server`

# Add policy and 2 secrets key
`cd vault`
`./vault.sh` 

# Install CSI
`cd ../nomad`
`nomad run controller.nomad`
`nomad run node.nomad`
`nomad create volume mysql.volume`
`nomad create volume http.volume` # http server has to be stateful because images are stored here
`nomad volume status` # Access mode still empty, thats okay
`nomad run mysql.nomad`
`sudo ls /storage/mysql`
`nomad run httpd.nomad` 
`nomad run nginx.nomad`

# Check services in Consul

# Verify web app
http://www.service.inthepicture.photo

