locals {
  ingress_nginx_chart_yaml  = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.ingress_nginx_chart_name}/Chart.yaml"))
  cert_manager_chart_yaml   = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.cert_manager_chart_name}/Chart.yaml"))
  selfsigned_chart_yaml     = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.selfsigned_chart_name}/Chart.yaml"))
  argocd_chart_yaml         = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.argocd_chart_name}/Chart.yaml"))
  valkey_chart_yaml         = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.valkey_chart_name}/Chart.yaml"))
  keycloak_chart_yaml       = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.keycloak_chart_name}/Chart.yaml"))
  postgresql_chart_yaml     = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.postgresql_chart_name}/Chart.yaml"))
  harbor_chart_yaml         = yamldecode(file("${path.module}/${var.helm_chart_path}/${var.harbor_chart_name}/Chart.yaml"))
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
  selfsigned_helm_values_path    = "../../${var.helm_values_path}/${var.selfsigned_chart_name}/values.yaml"
}

module "argo_cd" {
  source = "./modules/argo_cd"

  cluster_name                          = var.cluster_name
  argocd_chart_version                  = local.argocd_chart_yaml.version
  argocd_cache_chart_version            = local.valkey_chart_yaml.version
  argocd_helm_chart_path                = "../../${var.helm_chart_path}/${var.argocd_chart_name}"
  argocd_helm_values_path               = "../../${var.helm_values_path}/${var.argocd_chart_name}/values.yaml"
  argocd_cache_helm_chart_path          = "../../${var.helm_chart_path}/${var.valkey_chart_name}"
  argocd_cache_helm_values_path         = "../../${var.helm_values_path}/${var.argocd_chart_name}-cache/values.yaml"
  github_environments_repository_secret = var.github_environments_repository_secret
  github_environments_repository_pat    = var.github_environments_repository_pat
  github_environments_repository_url    = var.github_environments_repository_url

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
  keycloak_db_helm_values_path  = "../../${var.helm_values_path}/${var.keycloak_chart_name}-db/values.yaml"

  depends_on = [
    module.certificate_authorities,
    module.ingress_nginx,
   ]
}

module "harbor" {
  source = "./modules/harbor"

  cluster_name = var.cluster_name
  harbor_chart_version = local.harbor_chart_yaml.version
  harbor_cache_chart_version = local.valkey_chart_yaml.version
  harbor_db_chart_version = local.postgresql_chart_yaml.version
  harbor_helm_chart_path = "../../${var.helm_chart_path}/${var.harbor_chart_name}"
  harbor_helm_values_path = "../../${var.helm_values_path}/${var.harbor_chart_name}/values.yaml"
  harbor_cache_helm_chart_path = "../../${var.helm_chart_path}/${var.valkey_chart_name}"
  harbor_cache_helm_values_path = "../../${var.helm_values_path}/${var.harbor_chart_name}-cache/values.yaml"
  harbor_db_helm_chart_path = "../../${var.helm_chart_path}/${var.postgresql_chart_name}"
  harbor_db_helm_values_path = "../../${var.helm_values_path}/${var.harbor_chart_name}-db/values.yaml"

  depends_on = [
    module.certificate_authorities,
    module.ingress_nginx,
   ]
}

module "argocd_custom_resources" {
  source = "./modules/argo_cd_custom_resources"

  app_project_path = "../../../argocd/project/chorus-build-t.yaml"
  application_set_path = "../../../argocd/applicationset/applicationset-chorus-build-t.yaml"

  depends_on = [ module.argo_cd ]
}

# Outputs

data "kubernetes_service" "loadbalancer" {
  metadata {
    name = "${var.cluster_name}-ingress-nginx-controller"
    namespace = module.ingress_nginx.ingress_nginx_namespace
  }
}

output "loadbalancer_ip" {
  value = try(data.kubernetes_service.loadbalancer.status.0.load_balancer.0.ingress.0.ip,
              "Failed to retrieve loadbalancer IP address")
}

output "argocd_url" {
  value = try(module.argo_cd.argocd_url,
              "Failed to retrieve ArgoCD URL")
}

output "argocd_username" {
  value = try(module.argo_cd.argocd_username,
              "Failed to retrieve ArgoCD admin username ")
}

output "argocd_password" {
  value = module.argo_cd.argocd_password
  sensitive = true
}

output "harbor_url" {
  value = try(module.harbor.harbor_url,
              "Failed to retrieve Harbor URL")
}

output "harbor_username" {
  value = try(module.harbor.harbor_username,
              "Failed to retrieve Harbor URL")
}

output "harbor_password" {
  value = module.harbor.harbor_password
  sensitive = true
}

output "keycloak_url" {
  value = try(module.keycloak.keycloak_url,
              "Failed to retrieve Keycloak URL")
}

output "keycloak_username" {
  value = try(module.keycloak.keycloak_username,
              "Failed to retrieve Keycloak admin username")
}

output "keycloak_password" {
  value = module.keycloak.keycloak_password
  sensitive = true
}
