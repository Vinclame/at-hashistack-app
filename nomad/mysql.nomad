job "mysql" {
  datacenters = ["velp"]
  type = "service"

  group "mysql-server" {
    count = 1

    volume "mysql" {
      type            = "csi"
      source          = "mysql"
      read_only       = false
      attachment_mode = "file-system"
      access_mode     = "multi-node-multi-writer"
    }

    network {
      port "db" {
        to = 3306
      } 
    }

    task "mysql-server" {
      driver = "docker"

      vault {
        policies = ["mysql-access"]
      }

      config {
        image = "mysql:8.0"
        ports = ["db"]

        volumes = [
          "docker-entrypoint-initdb.d/:/docker-entrypoint-initdb.d/",
        ]
      }

      volume_mount {
        volume      = "mysql"
        destination = "/var/lib/mysql"
      }      

      template {
        data = <<EOH
{{ with secret "kv/data/mysql" }}
{{- if .Data.data.MYSQL_ROOT_PASSWORD }}
MYSQL_ROOT_PASSWORD ="{{ .Data.data.MYSQL_ROOT_PASSWORD }}"
{{ else }}
MYSQL_ROOT_PASSWORD="mysecret"
{{ end }}
{{ end }}
EOH
        destination = "mysql-server.env"
        env = true
      }

      template {
        data = <<EOH
CREATE DATABASE inthepicture;
CREATE TABLE inthepicture.photos ( id INT NOT NULL AUTO_INCREMENT, file_name varchar(255) COLLATE utf8_unicode_ci NOT NULL, uploaded_on datetime NOT NULL, status enum('1','0') COLLATE utf8_unicode_ci NOT NULL DEFAULT '1', PRIMARY KEY (id) ) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_unicode_ci;
{{ with secret "kv/data/mysql" }}
{{- if .Data.data.MYSQL_GURU_PASSWORD }}
{{ $passwd := .Data.data.MYSQL_GURU_PASSWORD }}
CREATE USER 'guru'@'%' IDENTIFIED with mysql_native_password BY '{{ $passwd }}';
{{ end }}
{{ end }}
GRANT ALL PRIVILEGES ON inthepicture.* TO 'guru'@'%';
EOH
        destination = "/docker-entrypoint-initdb.d/db.sql"
      }

      service {
        name = "mysql"
        port = "db"
        tags = ["mysql-container"]

        check {
          type     = "tcp"
          interval = "10s"
          timeout  = "2s"
        }
      }
      
      resources {
        cpu = 500
        memory = 1024
      }
    }
  }
}
