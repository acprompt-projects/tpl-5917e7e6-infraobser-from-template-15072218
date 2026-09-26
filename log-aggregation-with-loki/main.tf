terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_network" "observability" {
  name = "observability-net"
}

resource "docker_volume" "loki_data" {
  name = "loki-data"
}

resource "docker_image" "loki" {
  name         = "grafana/loki:2.9.3"
  keep_locally = true
}

resource "docker_image" "promtail" {
  name         = "grafana/promtail:2.9.3"
  keep_locally = true
}

resource "docker_container" "loki" {
  name  = "loki"
  image = docker_image.loki.image_id
  networks_advanced {
    name = docker_network.observability.name
  }
  ports {
    internal = 3100
    external = 3100
  }
  volumes {
    volume_name    = docker_volume.loki_data.name
    container_path = "/loki"
  }
  volumes {
    host_path      = abspath("${path.module}/loki-config.yml")
    container_path = "/etc/loki/local-config.yaml"
  }
  command = ["-config.file=/etc/loki/local-config.yaml"]
  restart = "unless-stopped"
}

resource "docker_container" "promtail" {
  name  = "promtail"
  image = docker_image.promtail.image_id
  networks_advanced {
    name = docker_network.observability.name
  }
  volumes {
    host_path      = "/var/log"
    container_path = "/var/log"
    read_only      = true
  }
  volumes {
    host_path      = "/var/lib/docker/containers"
    container_path = "/var/lib/docker/containers"
    read_only      = true
  }
  volumes {
    host_path      = abspath("${path.module}/promtail-config.yml")
    container_path = "/etc/promtail/config.yml"
  }
  command = ["-config.file=/etc/promtail/config.yml"]
  restart = "unless-stopped"
  depends_on = [docker_container.loki]
}

output "loki_endpoint" {
  value       = "http://loki:3100"
  description = "Loki API endpoint on the observability network"
}

output "loki_host_endpoint" {
  value       = "http://localhost:3100"
  description = "Loki API endpoint from the host"
}