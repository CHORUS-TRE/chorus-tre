# Read values
locals {
  helm_values = file("${path.module}/${var.helm_values_path}")
  helm_values_parsed = yamldecode(local.helm_values)
  ingress_nginx_namespace = local.helm_values_parsed.namespaceOverride
}

# Namespace Definitions
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = local.ingress_nginx_namespace
  }
}

# Ingress-Nginx Deployment
resource "helm_release" "ingress_nginx" {
  name       = "${var.cluster_name}-ingress-nginx"
  namespace  = local.ingress_nginx_namespace
  chart      = "${path.module}/${var.helm_chart_path}"
  version    = var.chart_version
  create_namespace = false
  wait       = true
  values = [ local.helm_values ]

  depends_on = [ kubernetes_namespace.ingress_nginx ]
}

resource "null_resource" "wait_for_lb_ip" {
  depends_on = [ helm_release.ingress_nginx ]

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    quiet = true
    command = <<EOT
    set -e
    for i in {1..30}; do
      IP=$(kubectl get svc ${var.cluster_name}-ingress-nginx-controller -n ${local.ingress_nginx_namespace} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
      if [ ! -z $IP ]; then
        exit 0
      fi
      echo "Waiting for LoadBalancer IP..."
      sleep 10
    done
    echo "Timed out waiting for LoadBalancer IP" >&2
    exit 1
    EOT
  }
}

data "kubernetes_service" "loadbalancer" {
  metadata {
    name = "${var.cluster_name}-ingress-nginx-controller"
    namespace = local.ingress_nginx_namespace
  }

  depends_on = [ null_resource.wait_for_lb_ip ]
}

output "loadbalancer_ip" {
  value = data.kubernetes_service.loadbalancer.status.0.load_balancer.0.ingress.0.ip
  depends_on = [ null_resource.wait_for_lb_ip ]
}

output "ingress_nginx_namespace" {
  value = local.ingress_nginx_namespace
}