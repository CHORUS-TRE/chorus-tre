resource "kubernetes_namespace" "keycloak" {
  metadata {
    name = var.namespace
  }
}

locals {
    keycloak_values = file(var.keycloak_helm_values_path)
    keycloak_values_parsed = yamldecode(local.keycloak_values)
    keycloak_existing_secret = local.keycloak_values_parsed.keycloak.auth.existingSecret
    keycloak_password_secret_key = local.keycloak_values_parsed.keycloak.auth.passwordSecretKey

    keycloak_db_values = file(var.keycloak_db_helm_values_path)
    keycloak_db_values_parsed = yamldecode(local.keycloak_db_values)
    keycloak_db_existing_secret = local.keycloak_db_values_parsed.postgresql.global.postgresql.auth.existingSecret
}

# Secrets
data "kubernetes_secret" "existing_secret_keycloak_db" {
  metadata {
    name = local.keycloak_db_existing_secret
    namespace = var.namespace
  }
}

resource "random_password" "keycloak_db_password" {
  length  = 32
  special = false
}

# TODO: double-check the hardcoded strings
resource "kubernetes_secret" "keycloak_db_secret" {
  metadata {
    name = local.keycloak_db_existing_secret
    namespace = var.namespace
  }
  data = {
    postgres-password = "postgres"
    password = coalesce(
      try(data.kubernetes_secret.keycloak_db_secret.data["password"], null),
      random_password.keycloak_db_password.result
    )
  }

  lifecycle {
    ignore_changes = [data["password"]]
  }
}

data "kubernetes_secret" "existing_secret_keycloak" {
  metadata {
    name = local.keycloak_existing_secret
    namespace = var.namespace
  }
}

resource "random_password" "keycloak_password" {
  length  = 32
  special = false
}

resource "kubernetes_secret" "keycloak_secret" {
  metadata {
    name = local.keycloak_existing_secret
    namespace = var.namespace
  }
  data = {
    local.keycloak_password_secret_key = coalesce(
      try(data.kubernetes_secret.keycloak_secret.data[local.keycloak_password_secret_key], null),
      random_password.keycloak_password.result
    )
  }

  lifecycle {
    ignore_changes = [data[local.keycloak_password_secret_key]]
  }
}

# Keycloak DB (PostgreSQL) Deployment
resource "helm_release" "keycloak_db" {
  name       = "${var.cluster_name}-keycloak-db"
  namespace  = var.namespace
  chart      = "${path.module}/${var.keycloak_db_helm_chart_path}"
  version    = var.keycloak_db_chart_version
  create_namespace = false
  wait       = true

  values = [ local.keycloak_db_values ]
}

# Keycloak Deployment
resource "helm_release" "keycloak" {
  name       = "${var.cluster_name}-keycloak"
  namespace  = var.namespace
  chart      = "${path.module}/${var.keycloak_db_helm_chart_path}"
  version    = var.keycloak_db_chart_version
  create_namespace = false
  wait       = true

  values = [ local.keycloak_values ]

  set {
    name = "keycloak.ingress.hostname"
    value = "auth.${var.subdomain_name}.${var.domain_name}"
  }
  # TODO: fetch "keycloak-db-postgresql" dynamically
  set {
    name = "keycloak.externalDatabase.host"
    value = "${var.cluster_name}-keycloak-db-postgresql"
  }
}