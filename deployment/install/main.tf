locals {
  ingress_nginx_chart_yaml  = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.ingress_nginx_chart_name}/Chart.yaml"))
  cert_manager_chart_yaml   = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.cert_manager_chart_name}/Chart.yaml"))
  selfsigned_chart_yaml     = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.selfsigned_chart_name}/Chart.yaml"))
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

module "certificate_authorities" {
  source = "./modules/certificate_authorities"

  cluster_name                   = var.cluster_name
  cert_manager_chart_version     = local.cert_manager_chart_yaml.version
  cert_manager_app_version       = local.cert_manager_chart_yaml.appVersion
  selfsigned_chart_version       = local.selfsigned_chart_yaml.version
  cert_manager_helm_chart_path   = "../../${var.helm_chart_path}/${var.cert_manager_chart_name}"
  cert_manager_helm_values_path  = "../../${var.helm_values_path}/${var.cert_manager_chart_name}/values.yaml"
  selfsigned_helm_chart_path     = "../../${var.helm_chart_path}/${var.selfsigned_chart_name}"
  selfsigned_helm_values_path  = "../../${var.helm_values_path}/${var.selfsigned_chart_name}/values.yaml"
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
    module.certificate_authorities,
    module.ingress_nginx,
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

  depends_on = [
    module.certificate_authorities,
    module.ingress_nginx,
   ]
}

module "custom_resources" {
  source = "./modules/custom_resources"
  depends_on = [ module.argo_cd]
}