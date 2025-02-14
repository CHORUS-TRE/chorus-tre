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
    command = "./hooks/pre-install/cert-manager-crds.sh"
    when    = create
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

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.cert_manager
  ]

  lifecycle {
    ignore_changes = [values]
  }

  # Pre-Delete Hook
  provisioner "local-exec" {
    command = "./hooks/pre-delete/argo-cd-crds.sh"
    when    = destroy
  }

  # Post-Delete Hook
  provisioner "local-exec" {
    command = "./hooks/post-delete/argo-cd-crds.sh"
    when    = destroy
  }
}
