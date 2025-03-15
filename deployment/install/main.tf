provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}

# Namespace Definitions
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

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
resource "kubernetes_secret" "argo_cd_cache" {
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

# Ingress-Nginx Deployment
resource "helm_release" "ingress_nginx" {
  name       = "${var.cluster_name}-ingress-nginx"
  namespace  = "ingress-nginx"
  chart      = "../../charts/ingress-nginx"
  version    = "0.0.4"
  create_namespace = false # Namespace is created separately
  wait       = true

  depends_on = [kubernetes_namespace.ingress_nginx]
}

# Cert-Manager Deployment
resource "helm_release" "cert_manager" {
  name       = "${var.cluster_name}-cert-manager"
  namespace  = "cert-manager"
  chart      = "../../charts/cert-manager"
  version    = "0.0.10"
  create_namespace = false
  wait       = true

  depends_on = [
    kubernetes_namespace.cert_manager,
    helm_release.ingress_nginx
  ]

  lifecycle {
    ignore_changes = [values]
  }

  provisioner "local-exec" {
    command = "${path.module}/hooks/pre-install/cert-manager-crds.sh"
    when    = create
  }
}

# Valkey Deployment
resource "helm_release" "valkey" {
  name       = "${var.cluster_name}-argo-cd-cache"
  namespace  = "argocd"
  chart      = "../../charts/valkey"
  version    = "0.0.8"
  create_namespace = false
  wait       = true

  values = [
    file("${path.module}/../../../environment-template/chorus-build/argo-cd-cache/values.yaml")
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
    kubernetes_secret.argo_cd_cache,
    helm_release.cert_manager
  ]

  lifecycle {
    ignore_changes = [values]
  }
}

# Argo-CD Deployment
resource "helm_release" "argo_cd" {
  name       = "${var.cluster_name}-argo-cd"
  namespace  = "argocd"
  chart      = "../../charts/argo-cd"
  version    = "0.0.30"
  create_namespace = false
  wait       = true

  values = [
    file("${path.module}/../../../environment-template/chorus-build/argo-cd/values.yaml")
  ]

  set {
    name  = "argo-cd.global.domain"
    value = "argo-cd.${var.subdomain_name}.${var.domain_name}"
  }

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.valkey
  ]

  lifecycle {
    ignore_changes = [values]
  }

  provisioner "local-exec" {
    command = "${path.module}/hooks/post-install/build-appset.sh"
    when    = create
  }

  provisioner "local-exec" {
    command = "${path.module}/hooks/pre-delete/argo-cd-crds.sh"
    when    = destroy
  }

  provisioner "local-exec" {
    command = "${path.module}/hooks/post-delete/argo-cd-crds.sh"
    when    = destroy
  }
}
