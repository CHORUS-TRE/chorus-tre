# Read values
locals {
  argocd_values = file("${path.module}/${var.argocd_helm_values_path}")
  argocd_values_parsed = yamldecode(local.argocd_values)
  argocd_namespace = local.argocd_values_parsed.argo-cd.namespaceOverride
  argocd_cache_values = file("${path.module}/${var.argocd_cache_helm_values_path}")
  argocd_cache_values_parsed = yamldecode(local.argocd_cache_values)
  argocd_cache_existing_secret = local.argocd_cache_values_parsed.valkey.auth.existingSecret
  argocd_cache_existing_secret_key = local.argocd_cache_values_parsed.valkey.auth.existingSecretPasswordKey
  argocd_cache_existing_user_key = "redis-username"
}

resource "kubernetes_namespace" "argocd" {
  metadata {
    name = local.argocd_namespace
  }
}

# Secret Definitions
# Check if the Kubernetes secret already exists
data "kubernetes_secret" "existing_secret_argocd_cache" {
  metadata {
    name = local.argocd_cache_existing_secret
    namespace = local.argocd_namespace
  }

  depends_on = [ kubernetes_namespace.argocd ]
}

resource "random_password" "redis_password" {
  length  = 32
  special = false
}

# Create Kubernetes secret using existing password (if found) or using the randomly generated one
resource "kubernetes_secret" "argocd_cache" {
  metadata {
    name = local.argocd_cache_existing_secret
    namespace = local.argocd_namespace
  }

  data = {
    # TODO: double check why user is empty string (copied from chorus-build)
    "${local.argocd_cache_existing_user_key}"   = ""
    "${local.argocd_cache_existing_secret_key}" = try(data.kubernetes_secret.existing_secret_argocd_cache.data["${local.argocd_cache_existing_secret_key}"],
                                                      random_password.redis_password.result)
  }

  lifecycle {
    ignore_changes = [ data ]
  }
}

resource "kubernetes_secret" "environments_repository_credentials" {
  metadata {
    name = var.github_environments_repository_secret
    namespace = local.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    url      = var.github_environments_repository_url
    password = var.github_environments_repository_pat
    type     = "git"
  }

  depends_on = [ kubernetes_namespace.argocd ]
}

resource "kubernetes_secret" "oci-build" {
  metadata {
    name = "oci-repository-build"
    namespace = local.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    enableOCI = "true"
    name      = "chorus-build-harbor"
    password  = var.harbor_robot_password
    type      = "helm"
    url       = "harbor.build-t.chorus-tre.ch"
    username  = join("", ["robot$", var.harbor_robot_username])
  }

  depends_on = [ kubernetes_namespace.argocd ]
}


/*
# Note: in-cluster is created by default in ArgoCD
Remote cluster configuration will be done in a second development round

resource "kubernetes_secret" "remote_cluster" {
  metadata {
    name = TODO
    namespace = local.argocd_namespace
    labels = {
      "argocd.argoproj.io/secret-type" = "cluster"
    }

    data = {
      name = TODO
      server = TODO
      config = TODO
    }
  }
}
IDEA: take the path to the config.json file as module input,
read the file in the locals block at the top of this file and
inject it in the secret

{
  "bearerToken": "<token>",
  "tlsClientConfig": {
    "insecure": false,
    "caData": "<base64-encoded-ca-cert>"
  }
}

*/

# ArgoCD Cache (Valkey) Deployment
resource "helm_release" "argocd_cache" {
  name       = "${var.cluster_name}-argo-cd-cache"
  namespace  = local.argocd_namespace
  chart      = "${path.module}/${var.argocd_cache_helm_chart_path}"
  version    = var.argocd_cache_chart_version
  create_namespace = false
  wait       = true

  values = [ local.argocd_cache_values ]

  set {
    name  = "valkey.metrics.enabled"
    value = "false"
  }
  set {
    name  = "valkey.metrics.serviceMonitor.enabled"
    value = "false"
  }
  set {
    name  = "valkey.metrics.podMonitor.enabled"
    value = "false"
  }

  depends_on = [
    kubernetes_namespace.argocd,
    kubernetes_secret.argocd_cache
  ]

  lifecycle {
    ignore_changes = [ values ]
  }
}

# ArgoCD Deployment
resource "helm_release" "argocd" {
  name       = "${var.cluster_name}-argo-cd"
  namespace  = local.argocd_namespace
  chart      = "${path.module}/${var.argocd_helm_chart_path}"
  version    = var.argocd_chart_version
  create_namespace = false
  wait       = true
  skip_crds  = false

  values = [ local.argocd_values ]

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.argocd_cache
  ]

  # TODO: double check why we want to ignor changes
  lifecycle {
    ignore_changes = [ values ]
  }
}

# ArgoCD initial credentials
data "kubernetes_secret" "argocd_admin_password" {
  metadata {
    name = "argocd-initial-admin-secret"
    namespace = local.argocd_namespace
  }

  depends_on = [ helm_release.argocd ]
}

output "argocd_url" {
  value = "https://${local.argocd_values_parsed.argo-cd.global.domain}"
}

output "argocd_grpc_url" {
  value = "https://grpc.${local.argocd_values_parsed.argo-cd.global.domain}"
}

output "argocd_username" {
  # admin username cannot be modified in the chart, only enabled/disabled
  value = "admin"
  description = "ArgoCD username"
}

output "argocd_password" {
  value = data.kubernetes_secret.argocd_admin_password.data.password
  description = "ArgoCD password"
  sensitive = true
}
