locals {
  ingress_nginx_chart_yaml = yamldecode(file("../${var.helm_chart_path}/${var.ingress_nginx_chart_name}/Chart.yaml"))
  cert_manager_chart_yaml  = yamldecode(file("../${var.helm_chart_path}/${var.cert_manager_chart_name}/Chart.yaml"))
  selfsigned_chart_yaml    = yamldecode(file("../${var.helm_chart_path}/${var.selfsigned_chart_name}/Chart.yaml"))
  valkey_chart_yaml        = yamldecode(file("../${var.helm_chart_path}/${var.valkey_chart_name}/Chart.yaml"))
  keycloak_chart_yaml      = yamldecode(file("../${var.helm_chart_path}/${var.keycloak_chart_name}/Chart.yaml"))
  postgresql_chart_yaml    = yamldecode(file("../${var.helm_chart_path}/${var.postgresql_chart_name}/Chart.yaml"))
  harbor_chart_yaml        = yamldecode(file("../${var.helm_chart_path}/${var.harbor_chart_name}/Chart.yaml"))
}

# Install charts

module "ingress_nginx" {
  source = "../modules/ingress_nginx"

  cluster_name     = var.cluster_name
  chart_version    = local.ingress_nginx_chart_yaml.version
  helm_chart_path  = "../../${var.helm_chart_path}/${var.ingress_nginx_chart_name}"
  helm_values_path = "../../${var.helm_values_path}/${var.ingress_nginx_chart_name}/values.yaml"

  depends_on = [ null_resource.helm_pull ]
}

module "certificate_authorities" {
  source = "../modules/certificate_authorities"

  cluster_name                  = var.cluster_name
  cert_manager_chart_version    = local.cert_manager_chart_yaml.version
  cert_manager_app_version      = local.cert_manager_chart_yaml.appVersion
  selfsigned_chart_version      = local.selfsigned_chart_yaml.version
  cert_manager_helm_chart_path  = "../../${var.helm_chart_path}/${var.cert_manager_chart_name}"
  cert_manager_helm_values_path = "../../${var.helm_values_path}/${var.cert_manager_chart_name}/values.yaml"
  selfsigned_helm_chart_path    = "../../${var.helm_chart_path}/${var.selfsigned_chart_name}"
  selfsigned_helm_values_path   = "../../${var.helm_values_path}/${var.selfsigned_chart_name}/values.yaml"

  depends_on = [ null_resource.helm_pull ]
}

module "keycloak" {
  source = "../modules/keycloak"

  cluster_name                 = var.cluster_name
  keycloak_chart_version       = local.keycloak_chart_yaml.version
  keycloak_db_chart_version    = local.postgresql_chart_yaml.version
  keycloak_helm_chart_path     = "../../${var.helm_chart_path}/${var.keycloak_chart_name}"
  keycloak_helm_values_path    = "../../${var.helm_values_path}/${var.keycloak_chart_name}/values.yaml"
  keycloak_db_helm_chart_path  = "../../${var.helm_chart_path}/${var.postgresql_chart_name}"
  keycloak_db_helm_values_path = "../../${var.helm_values_path}/${var.keycloak_chart_name}-db/values.yaml"

  depends_on = [
    null_resource.helm_pull,
    module.certificate_authorities,
    module.ingress_nginx,
  ]
}

resource "random_password" "harbor_keycloak_client_secret" {
  length  = 32
  special = false
}

resource "random_password" "argocd_keycloak_client_secret" {
  length  = 32
  special = false
}

module "harbor" {
  source = "../modules/harbor"

  cluster_name                  = var.cluster_name
  harbor_chart_version          = local.harbor_chart_yaml.version
  harbor_cache_chart_version    = local.valkey_chart_yaml.version
  harbor_db_chart_version       = local.postgresql_chart_yaml.version
  harbor_helm_chart_path        = "../../${var.helm_chart_path}/${var.harbor_chart_name}"
  harbor_helm_values_path       = "../../${var.helm_values_path}/${var.harbor_chart_name}/values.yaml"
  harbor_cache_helm_chart_path  = "../../${var.helm_chart_path}/${var.valkey_chart_name}"
  harbor_cache_helm_values_path = "../../${var.helm_values_path}/${var.harbor_chart_name}-cache/values.yaml"
  harbor_db_helm_chart_path     = "../../${var.helm_chart_path}/${var.postgresql_chart_name}"
  harbor_db_helm_values_path    = "../../${var.helm_values_path}/${var.harbor_chart_name}-db/values.yaml"
  oidc_client_id                = var.harbor_keycloak_client_id
  oidc_client_secret            = random_password.harbor_keycloak_client_secret.result
  oidc_endpoint                 = join("/", [module.keycloak.keycloak_url, "realms", var.keycloak_realm])
  oidc_admin_group              = var.harbor_keycloak_oidc_admin_group

  depends_on = [
    null_resource.helm_pull,
    module.certificate_authorities,
    module.ingress_nginx
  ]
}

# Outputs

output "loadbalancer_ip" {
  value = try(module.ingress_nginx.loadbalancer_ip,
  "Failed to retrieve loadbalancer IP address")
}

output "harbor_url" {
  value = try(module.harbor.harbor_url,
  "Failed to retrieve Harbor URL")
}

output "harbor_url_admin_login" {
  value = try(module.harbor.harbor_url_admin_login,
  "Failed to retrieve Harbor URL to login with local DB admin user")
}

output "harbor_username" {
  value = try(module.harbor.harbor_username,
  "Failed to retrieve Harbor URL")
}

output "harbor_password" {
  value     = module.harbor.harbor_password
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
  value     = module.keycloak.keycloak_password
  sensitive = true
}

locals {
  output = {
    loadbalancer_ip               = module.ingress_nginx.loadbalancer_ip
    harbor_url                    = module.harbor.harbor_url
    harbor_url_admin_login        = module.harbor.harbor_url_admin_login
    harbor_password               = module.harbor.harbor_password
    harbor_username               = module.harbor.harbor_username
    keycloak_url                  = module.keycloak.keycloak_url
    keycloak_username             = module.keycloak.keycloak_username
    keycloak_password             = module.keycloak.keycloak_password
    harbor_keycloak_client_secret = random_password.harbor_keycloak_client_secret.result
    argocd_keycloak_client_secret = random_password.argocd_keycloak_client_secret.result
  }
}

resource "local_file" "stage_01_output" {
  filename = "../stage_01_output.yaml"
  content  = yamlencode(local.output)
}