module "ingress_nginx" {
  source = "./modules/ingress_nginx"

  cluster_name = var.cluster_name
  chart_version = var.ingress_nginx_chart_version
  helm_chart_path = "../../${var.helm_chart_path}/ingress-nginx"
  helm_values_path = "../../${var.helm_values_path}/ingress-nginx/values.yaml"
}

module "cert_manager" {
  source = "./modules/cert_manager"

  cluster_name = var.cluster_name
  chart_version = var.cert_manager_chart_version
  app_version = var.cert_manager_app_version
  helm_chart_path = "../../${var.helm_chart_path}/cert-manager"
  helm_values_path = "../../${var.helm_values_path}/cert-manager/values.yaml"
}

module "argo_cd" {
  source = "./modules/argo_cd"

  cluster_name = var.cluster_name
  argocd_chart_version = var.argo_cd_chart_version
  argocd_cache_chart_version = var.valkey_chart_version
  argocd_helm_chart_path = "../../${var.helm_chart_path}/argo-cd"
  argocd_helm_values_path = "../../${var.helm_values_path}/argo-cd/values.yaml"
  argocd_cache_helm_chart_path = "../../${var.helm_chart_path}/valkey"
  argocd_cache_helm_values_path = "../../${var.helm_values_path}/argo-cd-cache/values.yaml"
  domain_name = var.domain_name
  subdomain_name = var.subdomain_name
  # we need to see if this order dependency is really needed
  depends_on = [
    module.cert_manager,
    module.ingress_nginx
  ]
}

module "keycloak" {
  source = "./modules/keycloak"

  cluster_name = var.cluster_name
  domain_name = var.domain_name
  subdomain_name = var.subdomain_name
  keycloak_chart_version = var.keycloak_chart_version
  keycloak_db_chart_version = var.postgresql_chart_version
  keycloak_db_helm_chart_path = "../../${var.helm_chart_path}/postgresql"
  keycloak_db_helm_values_path = "../../${var.helm_values_path}/keycloak-db/values.yaml"
  keycloak_helm_chart_path = "../../${var.helm_chart_path}/keycloak"
  keycloak_helm_values_path = "../../${var.helm_values_path}/keycloak/values.yaml"
  cluster_issuer = var.cluster_issuer
}

module "custom_resources" {
  source = "./modules/custom_resources"
  depends_on = [ module.argo_cd]
}