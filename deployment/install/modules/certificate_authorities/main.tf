# Read values
locals {
  cert_manager_helm_values = file("${path.module}/${var.cert_manager_helm_values_path}")
  cert_manager_helm_values_parsed = yamldecode(local.cert_manager_helm_values)
  cert_manager_namespace = local.cert_manager_helm_values_parsed.cert-manager.namespace
  selfsigned_helm_values = file("${path.module}/${var.selfsigned_helm_values_path}")
  selfsigned_helm_values_parsed = yamldecode(local.selfsigned_helm_values)
}

resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = local.cert_manager_namespace
  }
}

# Cert-Manager CRDs installation
data "http" "cert_manager_crds" {
  url = "https://github.com/cert-manager/cert-manager/releases/download/${var.cert_manager_app_version}/cert-manager.crds.yaml"

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
  namespace  = local.cert_manager_namespace
  chart      = "${path.module}/${var.cert_manager_helm_chart_path}"
  version    = var.cert_manager_chart_version
  create_namespace = false
  wait       = true
  skip_crds  = true

  values = [ local.cert_manager_helm_values ]

  depends_on = [
    kubernetes_namespace.cert_manager,
    kubernetes_manifest.cert_manager_crds
  ]

  lifecycle {
    ignore_changes = [ values ]
  }
}

resource "time_sleep" "wait_for_webhook" {
  depends_on = [ helm_release.cert_manager ]

  create_duration = "60s"
}

# Self-Signed Issuer (e.g. for PostgreSQL)
resource "helm_release" "selfsigned" {
  name       = "${var.cluster_name}-self-signed-issuer"
  namespace  = local.cert_manager_namespace
  chart      = "${path.module}/${var.selfsigned_helm_chart_path}"
  version    = var.selfsigned_chart_version
  create_namespace = false
  wait       = true

  values = [ local.selfsigned_helm_values ]

  depends_on = [ time_sleep.wait_for_webhook ]

  lifecycle {
    ignore_changes = [ values ]
  }
}