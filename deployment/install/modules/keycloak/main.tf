# Read values
locals {
    keycloak_values = file("${path.module}/${var.keycloak_helm_values_path}")
    keycloak_values_parsed = yamldecode(local.keycloak_values)
    keycloak_namespace = local.keycloak_values_parsed.keycloak.namespaceOverride
    keycloak_existing_secret = local.keycloak_values_parsed.keycloak.auth.existingSecret
    keycloak_password_secret_key = local.keycloak_values_parsed.keycloak.auth.passwordSecretKey

    keycloak_db_values = file("${path.module}/${var.keycloak_db_helm_values_path}")
    keycloak_db_values_parsed = yamldecode(local.keycloak_db_values)
    keycloak_db_existing_secret = local.keycloak_db_values_parsed.postgresql.global.postgresql.auth.existingSecret
    keycloak_db_admin_password_key = local.keycloak_db_values_parsed.postgresql.global.postgresql.auth.secretKeys.adminPasswordKey
    keycloak_db_postgres_password = local.keycloak_db_values_parsed.postgresql.global.postgresql.auth.postgresPassword
    keycloak_db_user_password_key = local.keycloak_db_values_parsed.postgresql.global.postgresql.auth.secretKeys.userPasswordKey
}

resource "kubernetes_namespace" "keycloak" {
  metadata {
    name = local.keycloak_namespace
  }
}

data "kubernetes_secret" "existing_secret_keycloak_db" {
  metadata {
    name = local.keycloak_db_existing_secret
    namespace = local.keycloak_namespace
  }
}

resource "random_password" "keycloak_db_password" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "keycloak_db_secret" {
  metadata {
    name = local.keycloak_db_existing_secret
    namespace = local.keycloak_namespace
  }
  data = {
    "${local.keycloak_db_admin_password_key}" = local.keycloak_db_postgres_password
    "${local.keycloak_db_user_password_key}" = try(data.kubernetes_secret.existing_secret_keycloak_db.data["${local.keycloak_db_user_password_key}"],
                                                   random_password.keycloak_db_password.result)
  }

  lifecycle {
    ignore_changes = [ data ]
  }
}

data "kubernetes_secret" "existing_secret_keycloak" {
  metadata {
    name = local.keycloak_existing_secret
    namespace = local.keycloak_namespace
  }
}

resource "random_password" "keycloak_password" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "keycloak_secret" {
  metadata {
    name = local.keycloak_existing_secret
    namespace = local.keycloak_namespace
  }
  data = {
    "${local.keycloak_password_secret_key}" = try(data.kubernetes_secret.existing_secret_keycloak.data["${local.keycloak_password_secret_key}"],
                                                  random_password.keycloak_password.result)
  }

  lifecycle {
    ignore_changes = [ data ]
  }
}

# Keycloak DB (PostgreSQL) Deployment
resource "helm_release" "keycloak_db" {
  name       = "${var.cluster_name}-keycloak-db"
  namespace  = local.keycloak_namespace
  chart      = "${path.module}/${var.keycloak_db_helm_chart_path}"
  version    = var.keycloak_db_chart_version
  create_namespace = false
  wait       = true

  values = [ local.keycloak_db_values ]

  set {
    name = "postgresql.metrics.enabled"
    value = "false"
  }
  set {
    name = "postgresql.metrics.serviceMonitor.enabled"
    value = "false"
  }
}

# Keycloak Deployment
resource "helm_release" "keycloak" {
  name       = "${var.cluster_name}-keycloak"
  namespace  = local.keycloak_namespace
  chart      = "${path.module}/${var.keycloak_helm_chart_path}"
  version    = var.keycloak_db_chart_version
  create_namespace = false
  wait       = true

  values = [ local.keycloak_values ]

  set {
    name = "keycloak.metrics.enabled"
    value = "false"
  }
  set {
    name = "keycloak.metrics.serviceMonitor.enabled"
    value = "false"
  }
}

data "kubernetes_secret" "keycloak_admin_password" {
  metadata {
    name = local.keycloak_values_parsed.keycloak.auth.existingSecret
    namespace = local.keycloak_namespace
  }

  depends_on = [ helm_release.keycloak ]
}

output "keycloak_url" {
  value = "https://${local.keycloak_values_parsed.keycloak.ingress.hostname}"
}


output "keycloak_password" {
  value = data.kubernetes_secret.keycloak_admin_password.data["${local.keycloak_values_parsed.keycloak.auth.passwordSecretKey}"]
  description = "Keycloak password"
  sensitive = true
}