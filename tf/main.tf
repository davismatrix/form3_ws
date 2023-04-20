terraform {
  required_version = ">= 1.0.7"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.15.0"
    }

    vault = {
      version = "3.0.1"
    }
  }
}

provider "vault" {
  address = var.vault_address
  token   = var.token
}

resource "vault_audit" "audit" {
  type = "file"

  options = {
    file_path = "/vault/logs/audit"
  }
}

resource "vault_auth_backend" "userpass" {
  type = "userpass"
}

resource "vault_generic_secret" "vgs" {
  for_each = {
    "service1" = "account"
    "service2" = "gateway"
    "service3" = "payment"
  }
  path = "secret/${var.environment}/${each.value}"

  data_json = <<EOT
{
  "db_user":   "${each.value}",
  "db_password": "965d3c27-9e20-4d41-91c9-61e6631870e7"
}
EOT
}

resource "vault_policy" "vp" {
  for_each = {
    "service1" = "account"
    "service2" = "gateway"
    "service3" = "payment"
  }
  name = "${each.value}-${var.environment}"

  policy = <<EOT

path "secret/data/${var.environment}/${each.value}" {
    capabilities = ["list", "read"]
}

EOT
}

resource "vault_generic_endpoint" "vge" {
  for_each = {
    "service1" = "account"
    "service2" = "gateway"
    "service3" = "payment"
  }
  depends_on           = [vault_auth_backend.userpass]
  path                 = "auth/userpass/users/${each.value}-${var.environment}"
  ignore_absent_fields = true

  data_json = <<EOT
{
  "policies": ["${each.value}-${var.environment}"],
  "password": "123-${each.value}-${var.environment}"
}
EOT
}

resource "docker_container" "service_container" {
  for_each = {
    "service1" = "account"
    "service2" = "gateway"
    "service3" = "payment"
  }
  image = "form3tech-oss/platformtest-${each.value}"
  name  = "${each.value}_${var.environment}"

  env = [
    "VAULT_ADDR=http://vault-${var.environment}:8200",
    "VAULT_USERNAME=${each.value}-${var.environment}",
    "VAULT_PASSWORD=123-${each.value}-${var.environment}",
    "ENVIRONMENT=${var.environment}"
  ]

  networks_advanced {
    name = "vagrant_${var.environment}"
  }

  lifecycle {
    ignore_changes = all
  }
}

resource "docker_container" "frontend_container" {
  image = "docker.io/nginx:1.22.0-alpine"
  name  = "frontend_${var.environment}"

  ports {
    internal = 80
    external = var.docker_port
  }

  networks_advanced {
    name = "vagrant_${var.environment}"
  }

  lifecycle {
    ignore_changes = all
  }
}
