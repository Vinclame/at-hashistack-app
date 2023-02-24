job "http" {
  datacenters = ["velp"]
  type        = "service"

  group "http" {
    count = 1

    volume "http" {
      type            = "csi"
      source          = "http"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    network {
      mode = "host"
      port "http" {
        to = 80
      }
    }

    service {
      name = "http"
      port = "http"
      tags = ["backend"]

      check {
        type     = "http"
        name     = "http-check"
        path     = "/check.php" # Returns 500 when db server is unreachable
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "http" {
      driver = "docker"

      vault {
        policies = ["mysql-access"]
      }

      env {
        NOMAD_CLIENT="${node.unique.name}"
      }

      config {
        image = "atcomp/inthepicture"
        ports = ["http"]
        force_pull = true
      }

      volume_mount {
        volume      = "http"
        destination = "/var/www/html/uploads"
      }

	  template { 
	    data = <<EOH
DBHOST="{{ range service "mysql" }}{{ .Address }}{{ end }}"
DBPORT="{{ range service "mysql" }}{{ .Port }}{{ end }}"
DBNAME = "inthepicture"
DBTABLENAME = "photos"
DBUSER = "guru"
{{ with secret "kv/data/mysql" }}
{{- if .Data.data.MYSQL_GURU_PASSWORD }}
DBPASS = "{{ .Data.data.MYSQL_GURU_PASSWORD }}"
{{ end }}
{{ end }}
EOH
        destination = "mysql-server.env"
        env         = true 
      }

      resources {
        cpu    = 500
        memory = 300
      }
    }
  }
}
