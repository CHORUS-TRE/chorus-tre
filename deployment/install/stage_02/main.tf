locals {
  harbor_values = file("../${var.helm_values_path}/${var.harbor_chart_name}/values.yaml")
  harbor_values_parsed = yamldecode(local.harbor_values)
  harbor_namespace = local.harbor_values_parsed.harbor.namespace
  harbor_existing_admin_password_secret = local.harbor_values_parsed.harbor.existingSecretAdminPassword
  harbor_existing_admin_password_secret_key = local.harbor_values_parsed.harbor.existingSecretAdminPasswordKey
  harbor_admin_password = data.kubernetes_secret.harbor_existing_admin_password.data["${local.harbor_existing_admin_password_secret_key}"]
  harbor_url = local.harbor_values_parsed.harbor.externalURL
  harbor_existing_oidc_secret = local.harbor_values_parsed.harbor.core.extraEnvVars.0.valueFrom.secretKeyRef.name
  harbor_existing_oidc_secret_key = local.harbor_values_parsed.harbor.core.extraEnvVars.0.valueFrom.secretKeyRef.key
  harbor_keycloak_client_secret = jsondecode(data.kubernetes_secret.harbor_oidc.data["${local.harbor_existing_oidc_secret_key}"]).oidc_client_secret

  keycloak_values = file("../${var.helm_values_path}/${var.keycloak_chart_name}/values.yaml")
  keycloak_values_parsed = yamldecode(local.keycloak_values)
  keycloak_namespace = local.keycloak_values_parsed.keycloak.namespaceOverride
  keycloak_existing_admin_password_secret = local.keycloak_values_parsed.keycloak.auth.existingSecret
  keycloak_existing_admin_password_secret_key = local.keycloak_values_parsed.keycloak.auth.passwordSecretKey
  keycloak_admin_password = data.kubernetes_secret.keycloak_existing_admin_password.data["${local.keycloak_existing_admin_password_secret_key}"]
  keycloak_url = "https://${local.keycloak_values_parsed.keycloak.ingress.hostname}"

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
      client_secret       = random_password.argocd_keycloak_client_secret.result
      root_url            = module.argo_cd.argocd_url
      base_url            = var.argocd_keycloak_base_url
      admin_url           = module.argo_cd.argocd_url
      web_origins         = [module.argo_cd.argocd_url]
      valid_redirect_uris = [join("/", [module.argo_cd.argocd_url, "auth/callback"])]
      client_group        = var.argocd_keycloak_oidc_admin_group
    }
  }
}

resource "random_password" "argocd_keycloak_client_secret" {
  length  = 32
  special = false
}

data "kubernetes_secret" "harbor_existing_admin_password" {
  metadata {
    name = local.harbor_existing_admin_password_secret
    namespace = local.harbor_namespace
  }
}

data "kubernetes_secret" "keycloak_existing_admin_password" {
  metadata {
    name = local.keycloak_existing_admin_password_secret
    namespace = local.keycloak_namespace
  }
}

data "kubernetes_secret" "harbor_oidc" {
  metadata {
    name = local.harbor_existing_oidc_secret
    namespace = local.harbor_namespace
  }
}

provider "keycloak" {
  alias     = "kcadmin-provider"
  client_id = "admin-cli"
  username  = var.keycloak_admin_username
  password  = local.keycloak_admin_password
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

  admin_id   = var.keycloak_admin_username
  realm_name = var.keycloak_realm
  clients_config = merge(
    local.harbor_keycloak_client_config,
    local.argocd_keycloak_client_config
  )
}

provider "harbor" {
  alias    = "harboradmin-provider"
  url      = local.harbor_url
  username = var.harbor_admin_username
  password = local.harbor_admin_password
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

  chorus_charts_revision    = var.chorus_charts_revision
  harbor_admin_username     = var.harbor_admin_username
  harbor_admin_password     = local.harbor_admin_password
  helm_chart_path           = "../../${var.helm_chart_path}"
  harbor_helm_values_path   = "../../${var.helm_values_path}/${var.harbor_chart_name}/values.yaml"
  argocd_robot_username     = var.argocd_harbor_robot_username
  argoci_robot_username     = var.argoci_harbor_robot_username
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

resource "null_resource" "wait_for_argocd" {

  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    quiet = true
    command = <<EOT
      set -e
      for i in {1..30}; do
        status=$(curl -skf -o /dev/null -w "%%{http_code}" ${module.argo_cd.argocd_url}/healthz)
        if [ "$status" -eq 200 ]; then
          exit 0
        else
          echo "Waiting for ArgoCD... ($i)"
          sleep 10
        fi
      done
      echo "Timed out waiting for ArgoCD" >&2
      exit 1
    EOT
  }

  depends_on = [ module.argo_cd ]
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
  oidc_client_secret                      = random_password.argocd_keycloak_client_secret.result
  helm_chart_repository_url               = replace(local.harbor_url, "https://", "")
  github_environments_repository_url      = var.github_environments_repository_url
  github_environments_repository_revision = var.github_environments_repository_revision

  depends_on = [
    module.argo_cd,
    null_resource.wait_for_argocd
  ]
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
  value     = module.harbor_config.argoci_robot_password
  sensitive = true
}

locals {
  output = {
    harbor_admin_username        = var.harbor_admin_username
    harbor_admin_password        = local.harbor_admin_password
    harbor_url                   = local.harbor_url
    harbor_argoci_robot_password = module.harbor_config.argoci_robot_password

    keycloak_admin_username   = var.keycloak_admin_username
    keycloak_admin_password   = local.keycloak_admin_password
    keycloak_url              = local.keycloak_url

    argocd_url      = module.argo_cd.argocd_url
    argocd_username = module.argo_cd.argocd_username
    argocd_password = module.argo_cd.argocd_password
  }
}

resource "local_file" "stage_02_output" {
  filename = "../output.yaml"
  content  = yamlencode(local.output)
}