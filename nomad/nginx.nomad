job "nginx" {
  datacenters = ["velp"]

  group "nginx" {
    count = 1

    network {
      port "http" {
        static = 80
        to = 8080
      }
    }

    service {
      name = "web"
      port = "http"
    }

    service {
      name = "test"
      port = "http"
    }

    task "nginx" {
      driver = "docker"

      config {
        image = "nginx"

        ports = ["http"]

        volumes = [
          "local:/etc/nginx/conf.d",
        ]
      }

      template {
        data = <<EOF
{{ $canary := "" }}
upstream test {
{{ range service "http" }}
{{ if in .Tags "test" }}
  server {{ .Address }}:{{ .Port }};
{{ $canary = "1" }} 
{{ break }}
{{ end -}} {{ end -}}
{{ if eq $canary "" }}
server 127.0.0.1:65535;
{{ end -}}
}
server {
   listen 8080;
   server_name  test.service.inthepicture.photo;
   client_max_body_size 5M;

   location / {
      proxy_pass http://test;
   }
}

upstream backend {
{{ range service "http" }}{{ if in .Tags "production" }}
  server {{ .Address }}:{{ .Port }};
{{ end }}{{ end }} }

server {
   listen 8080;
   server_name  web.service.inthepicture.photo;
   client_max_body_size 5M;

   location / {
      proxy_pass http://backend;
   }
}
EOF
        destination   = "local/load-balancer.conf"
        change_mode   = "signal"
        change_signal = "SIGHUP"
      }
    }
  }
}
