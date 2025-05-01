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
  # the depends_on raises issue for cert_manager
  # planning because the data "http" will not
  # be evaluated
  # we need to see if this order dependency is really needed
  #depends_on = [ module.ingress_nginx ]
}

module "argo_cd" {
  source = "./modules/argo_cd"
  cluster_name = var.cluster_name
  argo_cd_chart_version = var.argo_cd_chart_version
  valkey_chart_version = var.valkey_chart_version
  domain_name = var.domain_name
  subdomain_name = var.subdomain_name
  # we need to see if this order dependency is really needed
  depends_on = [
    module.cert_manager,
    module.ingress_nginx
  ]
}

module "custom_resources" {
  source = "./modules/custom_resources"
  depends_on = [ module.argo_cd]
}