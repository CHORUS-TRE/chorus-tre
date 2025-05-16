# Read values
locals {
  argocd_values = file("${path.module}/${var.argocd_helm_values_path}")
  argocd_values_parsed = yamldecode(local.argocd_values)
  argocd_namespace = local.argocd_values_parsed.argo-cd.namespaceOverride
  app_project = yamldecode(file("${path.module}/${var.app_project_path}"))
  application_set = yamldecode(file("${path.module}/${var.application_set_path}"))
  argocd_oidc_secret = "argocd-oidc"
}

resource "kubernetes_secret" "argocd_secret" {
  metadata {
    name = local.argocd_oidc_secret
    namespace = local.argocd_namespace
    labels = {
      "app.kubernetes.io/name" = local.argocd_oidc_secret
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    "keycloak.issuer"        = var.oidc_endpoint
    "keycloak.clientId"      = var.oidc_client_id
    "keycloak.clientSecret"  = var.oidc_client_secret
  }
}

/*
resource "kubernetes_manifest" "app_project" {
    manifest = local.app_project
}

resource "kubernetes_manifest" "application_set" {
    manifest = local.application_set
}
*/