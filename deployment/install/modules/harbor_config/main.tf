locals {
  harbor_values = file("${path.module}/${var.harbor_helm_values_path}")
  harbor_values_parsed = yamldecode(local.harbor_values)
  harbor_namespace = local.harbor_values_parsed.harbor.namespace
    oidc_secret = [
    for env in local.harbor_values_parsed.harbor.core.extraEnvVars : env
    if env.name == "CONFIG_OVERWRITE_JSON"
  ][0].valueFrom.secretKeyRef
  oidc_config = <<EOT
  {
  "auth_mode": "oidc_auth",
  "primary_auth_mode": "true",
  "oidc_name": "Keycloak",
  "oidc_endpoint": "${var.oidc_endpoint}",
  "oidc_client_id": "${var.oidc_client_id}",
  "oidc_client_secret": "${var.oidc_client_secret}",
  "oidc_groups_claim": "groups",
  "oidc_admin_group": "${var.oidc_admin_group}",
  "oidc_scope": "openid,profile,offline_access,email",
  "oidc_verify_cert": "false",
  "oidc_auto_onboard": "true",
  "oidc_user_claim": "name"
  }
  EOT
} #TODO: set oidc_verify_cert to "true"

resource "harbor_project" "projects" {
  for_each = toset(var.harbor_projects)

  name                   = each.key
  vulnerability_scanning = "false"
}

resource "random_password" "argocd_robot_password" {
  length  = 12
  special = false
}

resource "harbor_robot_account" "argocd" {
  name        = var.argocd_robot_username
  description = "ArgoCD robot account"
  level       = "system"
  secret      = random_password.argocd_robot_password.result
  permissions {
    access {
      action = "list"
      resource = "project"
    }
    kind = "system"
    namespace = "/"
  }
  # TODO: find a better way
  # to assign permissions per project aka namespace (apps, charts)
  permissions {
    access {
      action = "list"
      resource = "label"
    }
    access {
      action = "list"
      resource = "repository"
    }
    access {
      action = "list"
      resource = "tag"
    }
    access {
      action = "pull"
      resource = "repository"
    }
    access {
      action = "read"
      resource = "label"
    }
    access {
      action = "read"
      resource = "repository"
    }
    kind = "project"
    namespace = var.harbor_projects[0] # apps
  }
  permissions {
    access {
      action = "list"
      resource = "artifact"
    }
    access {
      action = "list"
      resource = "label"
    }
    access {
      action = "list"
      resource = "repository"
    }
    access {
      action = "pull"
      resource = "repository"
    }
    access {
      action = "read"
      resource = "artifact"
    }
    access {
      action = "read"
      resource = "label"
    }
    access {
      action = "read"
      resource = "project"
    }
    access {
      action = "read"
      resource = "repository"
    }
    kind = "project"
    namespace = var.harbor_projects[1] # charts
  }
}

resource "harbor_registry" "docker_hub" {
  provider_name = "docker-hub"
  name          = "Docker Hub"
  endpoint_url  = "https://hub.docker.com"
}

output "argocd_robot_password" {
  value = random_password.argocd_robot_password.result
  description = "Password of the robot user used by ArgoCD"
  sensitive = true
}

resource "kubernetes_secret" "oidc_secret" {
  metadata {
    name = local.oidc_secret.name
    namespace = local.harbor_namespace
  }

  data = {
    "${local.oidc_secret.key}" = local.oidc_config
  }

  lifecycle {
    ignore_changes = [ data ]
  }
}