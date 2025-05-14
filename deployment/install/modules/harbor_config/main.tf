resource "harbor_project" "apps" {
  name                   = "apps"
  vulnerability_scanning = "false"
}

resource "harbor_project" "charts" {
  name                   = "charts"
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
    namespace = harbor_project.apps.name
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
    namespace = harbor_project.charts.name
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