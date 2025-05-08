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
}

# Generate a random password (only if needed)
resource "random_password" "redis_password" {
  length  = 32
  special = false
}

# Create Kubernetes secret using existing password (if found) or generate a new one
resource "kubernetes_secret" "argocd_cache" {
  metadata {
    name = local.argocd_cache_existing_secret
    namespace = local.argocd_namespace
  }

  data = {
    "${local.argocd_cache_existing_user_key}"   = ""
    "${local.argocd_cache_existing_secret_key}" = try(data.kubernetes_secret.existing_secret_argocd_cache.data["${local.argocd_cache_existing_secret_key}"],
                                                      random_password.redis_password.result)
  }

  lifecycle {
    ignore_changes = [data]
  }
}

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
    ignore_changes = [values]
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

  lifecycle {
    ignore_changes = [values]
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
  value = "admin"
  description = "ArgoCD username"
}

output "argocd_password" {
  value = data.kubernetes_secret.argocd_admin_password.data.password
  description = "ArgoCD password"
  sensitive = true
}

/*
The kubernetes_ingress data source did not parse the objects correctly
this seems to be a terraform limitation

data "kubernetes_ingress" "argocd_server" {
  metadata {
    name = "${var.cluster_name}-argo-cd-argocd-server"
    namespace = local.argocd_namespace
  }

  depends_on = [ helm_release.argocd ]
}

data "kubernetes_ingress" "argocd_grpc" {
  metadata {
    name = "${var.cluster_name}-argo-cd-argocd-server-grpc"
    namespace = local.argocd_namespace
  }

  depends_on = [ helm_release.argocd ]
}

output "argocd_external_ip" {
  value = try(data.kubernetes_ingress.argocd_server.status.loadBalancer.ingress[0].ip,
              "Failed to fetch ArgoCD external IP")
  description = "ArgoCD server external IP"
}

output "argocd_grpc_external_ip" {
  value = try(data.kubernetes_ingress.argocd_grpc.status.loadBalancer.ingress[0].ip,
              "Failed to fetch ArgoCD GRPC external IP")
  description = "ArgoCD GRPC server external IP"
}
*/