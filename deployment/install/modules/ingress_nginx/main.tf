# Namespace Definitions
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = var.namespace
  }
}

# Ingress-Nginx Deployment
resource "helm_release" "ingress_nginx" {
  name       = "${var.cluster_name}-ingress-nginx"
  namespace  = var.namespace
  chart      = "../../charts/ingress-nginx"
  version    = var.chart_version
  create_namespace = false
  wait       = true

  depends_on = [kubernetes_namespace.ingress_nginx]
}