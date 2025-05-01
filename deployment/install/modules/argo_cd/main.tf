resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Secret Definitions
# Check if the Kubernetes secret already exists
data "kubernetes_secret" "existing_secret_argocd_cache" {
  metadata {
    name      = "argo-cd-cache-secret"
    namespace = "argocd"
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
    name      = "argo-cd-cache-secret"
    namespace = "argocd"
  }

  data = {
    redis-username = ""
    redis-password = coalesce(
      try(data.kubernetes_secret.existing_secret_argocd_cache.data["redis-password"], null),
      random_password.redis_password.result
    )
  }

  lifecycle {
    ignore_changes = [data["redis-password"]]
  }
}

# Valkey Deployment
resource "helm_release" "valkey" {
  name       = "${var.cluster_name}-argo-cd-cache"
  namespace  = "argocd"
  chart      = "../../charts/valkey"
  version    = var.valkey_chart_version
  create_namespace = false
  wait       = true

  values = [
    file("${path.module}/../../../../../environment-template/chorus-build/argo-cd-cache/values.yaml")
  ]

  set {
    name = "valkey.metrics.enabled"
    value = "false"
  }

  set {
    name = "valkey.metrics.serviceMonitor.enabled"
    value = "false"
  }

  set {
    name = "valkey.metrics.podMonitor.enabled"
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

# Argo-CD Deployment
resource "helm_release" "argocd" {
  name       = "${var.cluster_name}-argo-cd"
  namespace  = "argocd"
  chart      = "../../charts/argo-cd"
  version    = var.argo_cd_chart_version
  create_namespace = false
  wait       = true
  skip_crds  = false

  values = [
    file("${path.module}/../../../../../environment-template/chorus-build/argo-cd/values.yaml")
  ]

  set {
    name  = "argo-cd.global.domain"
    value = "argo-cd.${var.subdomain_name}.${var.domain_name}"
  }
  # Install the ArgoCD CRDs
  # when installing the chart
  set {
    name = "argo-cd.crds.install"
    value = "true"
  }
  # Delete the ArgoCD CRDs
  # when deleting the chart
  set {
    name = "argo-cd.crds.keep"
    value = "false"
  }

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.valkey
  ]

  lifecycle {
    ignore_changes = [values]
  }
}
