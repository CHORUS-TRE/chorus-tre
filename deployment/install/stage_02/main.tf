locals {
  stage_01_output               = yamldecode(file("../stage_01_output.yaml"))
  harbor_password               = local.stage_01_output.harbor_password
  harbor_url                    = local.stage_01_output.harbor_url
  harbor_username               = local.stage_01_output.harbor_username
  keycloak_password             = local.stage_01_output.keycloak_password
  keycloak_url                  = local.stage_01_output.keycloak_url
  keycloak_username             = local.stage_01_output.keycloak_username
  harbor_keycloak_client_secret = local.stage_01_output.harbor_keycloak_client_secret
  argocd_keycloak_client_secret = local.stage_01_output.argocd_keycloak_client_secret

  argocd_chart_yaml = yamldecode(file("../${var.helm_chart_path}/${var.argocd_chart_name}/Chart.yaml"))
  valkey_chart_yaml = yamldecode(file("../${var.helm_chart_path}/${var.valkey_chart_name}/Chart.yaml"))

  harbor_keycloak_client_config = {
    "${var.harbor_keycloak_client_id}" = {
      client_secret       = local.harbor_keycloak_client_secret
      root_url            = local.harbor_url
      base_url            = var.harbor_keycloak_base_url
      admin_url           = local.harbor_url
      web_origins         = [local.harbor_url]
      valid_redirect_uris = [join("/", [local.harbor_url, "c/oidc/callback"])]
      client_group        = var.harbor_keycloak_oidc_admin_group
    }
  }
  argocd_keycloak_client_config = {
    "${var.argocd_keycloak_client_id}" = {
      client_secret       = local.argocd_keycloak_client_secret
      root_url            = module.argo_cd.argocd_url
      base_url            = var.argocd_keycloak_base_url
      admin_url           = module.argo_cd.argocd_url
      web_origins         = [module.argo_cd.argocd_url]
      valid_redirect_uris = [join("/", [module.argo_cd.argocd_url, "auth/callback"])]
      client_group        = var.argocd_keycloak_oidc_admin_group
    }
  }
}

provider "keycloak" {
  alias     = "kcadmin-provider"
  client_id = "admin-cli"
  username  = local.keycloak_username
  password  = local.keycloak_password
  url       = local.keycloak_url
  # Ignoring certificate errors
  # because it might take some times
  # for certificates to be signed
  # by a trusted authority
  tls_insecure_skip_verify = true
}

module "keycloak_config" {
  source = "../modules/keycloak_config"

  providers = {
    keycloak = keycloak.kcadmin-provider
  }

  admin_id   = local.keycloak_username
  realm_name = var.keycloak_realm
  clients_config = merge(
    local.harbor_keycloak_client_config,
    local.argocd_keycloak_client_config
  )
}

provider "harbor" {
  alias    = "harboradmin-provider"
  url      = local.harbor_url
  username = local.harbor_username
  password = local.harbor_password
  # Ignoring certificate errors
  # because it might take some times
  # for certificates to be signed
  # by a trusted authority
  insecure = true
}

module "harbor_config" {
  source = "../modules/harbor_config"

  providers = {
    harbor = harbor.harboradmin-provider
  }

  harbor_helm_values_path = "../../${var.helm_values_path}/${var.harbor_chart_name}/values.yaml"
  argocd_robot_username   = var.argocd_harbor_robot_username
  argoci_robot_username   = var.argoci_harbor_robot_username
}

module "argo_cd" {
  source = "../modules/argo_cd"

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
  harbor_robot_username                 = var.argocd_harbor_robot_username
  harbor_robot_password                 = module.harbor_config.argocd_robot_password
}

provider "argocd" {
  alias       = "argocdadmin_provider"
  username    = module.argo_cd.argocd_username
  password    = module.argo_cd.argocd_password
  server_addr = join("", [replace(module.argo_cd.argocd_url, "https://", ""), ":443"])
  # Ignoring certificate errors
  # because it might take some times
  # for certificates to be signed
  # by a trusted authority
  insecure = true
}

module "argocd_config" {
  source = "../modules/argo_cd_config"

  providers = {
    argocd = argocd.argocdadmin_provider
  }

  argocd_helm_values_path                 = "../../${var.helm_values_path}/${var.argocd_chart_name}/values.yaml"
  cluster_name                            = var.cluster_name
  oidc_endpoint                           = join("/", [local.keycloak_url, "realms", var.keycloak_realm])
  oidc_client_id                          = var.argocd_keycloak_client_id
  oidc_client_secret                      = local.argocd_keycloak_client_secret
  helm_chart_repository_url               = local.harbor_url
  github_environments_repository_url      = var.github_environments_repository_url
  github_environments_repository_revision = var.github_environments_repository_revision

  depends_on = [module.argo_cd]
}

# Outputs

output "argocd_url" {
  value = try(module.argo_cd.argocd_url,
  "Failed to retrieve ArgoCD URL")
}

output "argocd_username" {
  value = try(module.argo_cd.argocd_username,
  "Failed to retrieve ArgoCD admin username ")
}

output "argocd_password" {
  value     = module.argo_cd.argocd_password
  sensitive = true
}

output "harbor_argoci_robot_password" {
  value     = module.argo_cd.argoci_robot_password
  sensitive = true
}

locals {
  output = {
    argocd_url      = module.argo_cd.argocd_url
    argocd_username = module.argo_cd.argocd_username
    argocd_password = module.argo_cd.argocd_password
    harbor_argoci_robot_password = module.argo_cd.argoci_robot_password
  }
}

resource "local_file" "stage_02_output" {
  filename = "../stage_02_output.yaml"
  content  = yamlencode(merge(local.output, local.stage_01_output))
}