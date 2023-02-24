job "storage-controller" {
  datacenters = ["velp"]
  type        = "service"

  group "controller" {
    task "controller" {
      driver = "docker"

      config {
        image = "registry.gitlab.com/rocketduck/csi-plugin-nfs:0.6.1"

        args = [
          "--type=controller",
          "--node-id=${attr.unique.hostname}",
          "--nfs-server=10.0.250.10:/storage",
          "--mount-options=defaults",
        ]

        network_mode = "host"
        privileged = true
      }

      csi_plugin {
        id        = "nfs"
        type      = "controller"
        mount_dir = "/csi"
      }

      resources {
        cpu    = 500
        memory = 256
      }

    }
  }
}
