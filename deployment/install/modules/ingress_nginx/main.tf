# Namespace Definitions
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = var.namespace
  }
}

locals {
  helm_values = file("${path.module}/${var.helm_values_path}")
}

# Ingress-Nginx Deployment
resource "helm_release" "ingress_nginx" {
  name       = "${var.cluster_name}-ingress-nginx"
  namespace  = var.namespace
  chart      = "${path.module}/${var.helm_chart_path}"
  version    = var.chart_version
  create_namespace = false
  wait       = true
  values = [ local.helm_values ]

  depends_on = [kubernetes_namespace.ingress_nginx]
}