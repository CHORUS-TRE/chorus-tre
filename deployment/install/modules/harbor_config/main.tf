locals {
  harbor_values = file("${path.module}/${var.harbor_helm_values_path}")
  harbor_values_parsed = yamldecode(local.harbor_values)
  harbor_namespace = local.harbor_values_parsed.harbor.namespace
}

data "harbor_projects" "existing_projects" {}

output "existing_projects" {
  value = data.harbor_projects.existing_projects
}

# TODO: check if project exists already
resource "harbor_project" "projects" {
  for_each = setsubtract(toset(var.harbor_projects), toset([for project in data.harbor_projects.existing_projects.projects : project.name]))

  name                   = each.key
  vulnerability_scanning = "false"
}

resource "random_password" "argocd_robot_password" {
  length  = 12
  special = false
  upper   = true
  lower   = true
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

  depends_on = [ harbor_project.projects ]
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