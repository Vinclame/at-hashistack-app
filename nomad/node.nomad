job "storage-node" {
  datacenters = ["velp"]
  type        = "system"

  group "node" {
    task "node" {
      driver = "docker"

      config {
        image = "registry.gitlab.com/rocketduck/csi-plugin-nfs:0.6.1"

        args = [
          "--type=node",
          "--node-id=${attr.unique.hostname}",
          "--nfs-server=10.0.250.10:/storage",
          "--mount-options=defaults",
        ]

        network_mode = "host"

        privileged = true
      }

      csi_plugin {
        id        = "nfs"
        type      = "node"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 500
        memory = 256
      }

    }
  }
}
