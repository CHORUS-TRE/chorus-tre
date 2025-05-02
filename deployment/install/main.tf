locals {
  ingress_nginx_chart_yaml  = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.ingress_nginx_chart_name}/Chart.yaml"))
  cert_manager_chart_yaml   = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.cert_manager_chart_name}/Chart.yaml"))
  argocd_chart_yaml         = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.argocd_chart_name}/Chart.yaml"))
  valkey_chart_yaml         = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.valkey_chart_name}/Chart.yaml"))
  keycloak_chart_yaml       = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.keycloak_chart_name}/Chart.yaml"))
  postgresql_chart_yaml     = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.postgresql_chart_name}/Chart.yaml"))

}

module "ingress_nginx" {
  source = "./modules/ingress_nginx"

  cluster_name      = var.cluster_name
  chart_version     = local.ingress_nginx_chart_yaml.version
  helm_chart_path   = "../../${var.helm_chart_path}/${var.ingress_nginx_chart_name}"
  helm_values_path  = "../../${var.helm_values_path}/${var.ingress_nginx_chart_name}/values.yaml"
}

module "cert_manager" {
  source = "./modules/cert_manager"

  cluster_name      = var.cluster_name
  chart_version     = local.cert_manager_chart_yaml.version
  app_version       = local.cert_manager_chart_yaml.appVersion
  helm_chart_path   = "../../${var.helm_chart_path}/${var.cert_manager_chart_name}"
  helm_values_path  = "../../${var.helm_values_path}/${var.cert_manager_chart_name}/values.yaml"
}

module "argo_cd" {
  source = "./modules/argo_cd"

  cluster_name                    = var.cluster_name
  argocd_chart_version            = local.argocd_chart_yaml.version
  argocd_cache_chart_version      = local.valkey_chart_yaml.version
  argocd_helm_chart_path          = "../../${var.helm_chart_path}/${var.argocd_chart_name}"
  argocd_helm_values_path         = "../../${var.helm_values_path}/${var.argocd_chart_name}/values.yaml"
  argocd_cache_helm_chart_path    = "../../${var.helm_chart_path}/${var.valkey_chart_name}"
  argocd_cache_helm_values_path   = "../../${var.helm_values_path}/argo-cd-cache/values.yaml"

  depends_on = [
    module.cert_manager,
    module.ingress_nginx
  ]
}

module "keycloak" {
  source = "./modules/keycloak"

  cluster_name                  = var.cluster_name
  keycloak_chart_version        = local.keycloak_chart_yaml.version
  keycloak_db_chart_version     = local.postgresql_chart_yaml.version
  keycloak_helm_chart_path      = "../../${var.helm_chart_path}/${var.keycloak_chart_name}"
  keycloak_helm_values_path     = "../../${var.helm_values_path}/${var.keycloak_chart_name}/values.yaml"
  keycloak_db_helm_chart_path   = "../../${var.helm_chart_path}/${var.postgresql_chart_name}"
  keycloak_db_helm_values_path  = "../../${var.helm_values_path}/keycloak-db/values.yaml"
}

module "custom_resources" {
  source = "./modules/custom_resources"
  depends_on = [ module.argo_cd]
}