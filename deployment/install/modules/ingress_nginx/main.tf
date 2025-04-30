# Namespace Definitions
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
  }
}

# Ingress-Nginx Deployment
resource "helm_release" "ingress_nginx" {
  name       = "${var.cluster_name}-ingress-nginx"
  namespace  = "ingress-nginx"
  chart      = "../../charts/ingress-nginx"
  version    = var.chart_version
  create_namespace = false # Namespace is created separately
  wait       = true

  depends_on = [kubernetes_namespace.ingress_nginx]
}