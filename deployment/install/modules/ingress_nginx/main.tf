# Read values
locals {
  helm_values = file("${path.module}/${var.helm_values_path}")
  helm_values_parsed = yamldecode(local.helm_values)
}

# Namespace Definitions
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = local.helm_values_parsed.namespaceOverride
  }
}

# Ingress-Nginx Deployment
resource "helm_release" "ingress_nginx" {
  name       = "${var.cluster_name}-ingress-nginx"
  namespace  = local.helm_values_parsed.namespaceOverride
  chart      = "${path.module}/${var.helm_chart_path}"
  version    = var.chart_version
  create_namespace = false
  wait       = true
  values = [ local.helm_values ]

  depends_on = [kubernetes_namespace.ingress_nginx]
}