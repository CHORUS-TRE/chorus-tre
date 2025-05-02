# Read values
locals {
  helm_values = file("${path.module}/${var.helm_values_path}")
  helm_values_parsed = yamldecode(local.helm_values)
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = local.helm_values_parsed.cert-manager.namespace
  }
}

# Cert-Manager CRDs installation
data "http" "cert_manager_crds" {
  url = "https://github.com/cert-manager/cert-manager/releases/download/${var.app_version}/cert-manager.crds.yaml"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Failed to download Cert-Manager CRDs: ${self.status_code}"
    }
  }
}

resource "kubernetes_manifest" "cert_manager_crds" {
    for_each = { for i, m in provider::kubernetes::manifest_decode_multi(data.http.cert_manager_crds.response_body) : i => m }
    manifest = each.value
    depends_on = [
      kubernetes_namespace.cert_manager,
      data.http.cert_manager_crds
    ]
}

# Cert-Manager deployment
resource "helm_release" "cert_manager" {
  name       = "${var.cluster_name}-cert-manager"
  namespace  = local.helm_values_parsed.cert-manager.namespace
  chart      = "${path.module}/${var.helm_chart_path}"
  version    = var.chart_version
  create_namespace = false
  wait       = true
  skip_crds  = true

  values = [ local.helm_values ]

  depends_on = [
    kubernetes_namespace.cert_manager,
    kubernetes_manifest.cert_manager_crds
  ]

  lifecycle {
    ignore_changes = [values]
  }
}