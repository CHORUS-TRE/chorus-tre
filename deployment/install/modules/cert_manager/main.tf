resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

output "debug_crds_version" {
  value = var.crds_version
}

# Cert-Manager CRDs installation
data "http" "cert_manager_crds" {
  url = "https://github.com/cert-manager/cert-manager/releases/download/${var.crds_version}/cert-manager.crds.yaml"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Failed to download CRDs: ${self.status_code}"
    }
  }
}

resource "kubernetes_manifest" "cert_manager_crds" {
    for_each = { for i, m in provider::kubernetes::manifest_decode_multi(data.http.cert_manager_crds.response_body) : i => m }
    manifest = each.value
    depends_on = [kubernetes_namespace.cert_manager]
}

# Cert-Manager deployment
resource "helm_release" "cert_manager" {
  name       = "${var.cluster_name}-cert-manager"
  namespace  = "cert-manager"
  chart      = "../../charts/cert-manager"
  version    = var.chart_version
  create_namespace = false
  wait       = true

  depends_on = [
    kubernetes_namespace.cert_manager
  ]

  lifecycle {
    ignore_changes = [values]
  }
}