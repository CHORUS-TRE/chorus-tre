locals {
  harbor_values = file("${path.module}/${var.harbor_helm_values_path}")
  harbor_values_parsed = yamldecode(local.harbor_values)
  harbor_namespace = local.harbor_values_parsed.harbor.namespace
  harbor_url = local.harbor_values_parsed.harbor.externalURL
}

resource "harbor_project" "projects" {
  for_each = toset([ "apps", "cache", "charts", "chorus", "docker_proxy", "services" ])

  name                   = each.key
  vulnerability_scanning = "false"
  force_destroy = true
}

# ArgoCD robot account

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
    namespace = "apps"
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
    namespace = "charts"
  }

  depends_on = [ harbor_project.projects ]
}

# ArgoCI robot account

resource "random_password" "argoci_robot_password" {
  length  = 12
  special = false
  upper   = true
  lower   = true
}

resource "harbor_robot_account" "argoci" {
  name        = var.argoci_robot_username
  description = "ArgoCI robot account"
  level       = "system"
  secret      = random_password.argoci_robot_password.result
  permissions {
    access {
      action = "list"
      resource = "project"
    }
    access {
      action = "create"
      resource = "registry"
    }
    access {
      action = "list"
      resource = "registry"
    }
    access {
      action = "read"
      resource = "registry"
    }
    access {
      action = "update"
      resource = "registry"
    }
    kind = "system"
    namespace = "/"
  }
  permissions {
    access {
      action = "create"
      resource = "artifact"
    }
    access {
      action = "list"
      resource = "artifact"
    }
    access {
      action = "read"
      resource = "artifact"
    }
    access {
      action = "create"
      resource = "artifact-label"
    }
    access {
      action = "create"
      resource = "label"
    }
    access {
      action = "list"
      resource = "label"
    }
    access {
      action = "read"
      resource = "label"
    }
    access {
      action = "update"
      resource = "label"
    }
    access {
      action = "list"
      resource = "metadata"
    }
    access {
      action = "read"
      resource = "metadata"
    }
    access {
      action = "read"
      resource = "project"
    }
    access {
      action = "delete"
      resource = "repository"
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
      action = "push"
      resource = "repository"
    }
    access {
      action = "read"
      resource = "repository"
    }
    access {
      action = "update"
      resource = "repository"
    }
    access {
      action = "create"
      resource = "sbom"
    }
    access {
      action = "read"
      resource = "sbom"
    }
    access {
      action = "create"
      resource = "scan"
    }
    access {
      action = "read"
      resource = "scan"
    }
    kind = "project"
    namespace = "apps"
  }

  permissions {
    access {
      action = "create"
      resource = "artifact"
    }
    access {
      action = "list"
      resource = "artifact"
    }
    access {
      action = "read"
      resource = "artifact"
    }
    access {
      action = "create"
      resource = "artifact-label"
    }
    access {
      action = "create"
      resource = "label"
    }
    access {
      action = "list"
      resource = "label"
    }
    access {
      action = "read"
      resource = "label"
    }
    access {
      action = "list"
      resource = "metadata"
    }
    access {
      action = "read"
      resource = "metadata"
    }
    access {
      action = "read"
      resource = "project"
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
      action = "push"
      resource = "repository"
    }
    access {
      action = "read"
      resource = "repository"
    }
    access {
      action = "update"
      resource = "repository"
    }
    access {
      action = "create"
      resource = "sbom"
    }
    access {
      action = "read"
      resource = "sbom"
    }
    access {
      action = "create"
      resource = "scanner"
    }
    access {
      action = "read"
      resource = "scanner"
    }
    access {
      action = "create"
      resource = "tag"
    }
    access {
      action = "list"
      resource = "tag"
    }
    kind = "project"
    namespace = "docker_proxy"
  }

  permissions {
    access {
      action = "list"
      resource = "artifact"
    }
    access {
      action = "read"
      resource = "artifact"
    }
    access {
      action = "create"
      resource = "artifact-label"
    }
    access {
      action = "create"
      resource = "label"
    }
    access {
      action = "list"
      resource = "label"
    }
    access {
      action = "read"
      resource = "label"
    }
    access {
      action = "update"
      resource = "label"
    }
    access {
      action = "list"
      resource = "metadata"
    }
    access {
      action = "read"
      resource = "metadata"
    }
    access {
      action = "read"
      resource = "project"
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
      action = "push"
      resource = "repository"
    }
    access {
      action = "read"
      resource = "repository"
    }
    access {
      action = "update"
      resource = "repository"
    }
    access {
      action = "create"
      resource = "sbom"
    }
    access {
      action = "read"
      resource = "sbom"
    }
    access {
      action = "create"
      resource = "scan"
    }
    access {
      action = "read"
      resource = "scan"
    }
        access {
      action = "create"
      resource = "tag"
    }
    access {
      action = "list"
      resource = "tag"
    }
    kind = "project"
    namespace = "charts"
  }

  permissions {
    access {
      action = "list"
      resource = "artifact"
    }
    access {
      action = "read"
      resource = "artifact"
    }
    access {
      action = "create"
      resource = "artifact-label"
    }
    access {
      action = "create"
      resource = "label"
    }
    access {
      action = "list"
      resource = "label"
    }
    access {
      action = "read"
      resource = "label"
    }
    access {
      action = "update"
      resource = "label"
    }
    access {
      action = "list"
      resource = "metadata"
    }
    access {
      action = "read"
      resource = "metadata"
    }
    access {
      action = "read"
      resource = "project"
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
      action = "push"
      resource = "repository"
    }
    access {
      action = "read"
      resource = "repository"
    }
    access {
      action = "update"
      resource = "repository"
    }
    access {
      action = "create"
      resource = "sbom"
    }
    access {
      action = "read"
      resource = "sbom"
    }
    access {
      action = "create"
      resource = "scan"
    }
    access {
      action = "read"
      resource = "scan"
    }
    access {
      action = "create"
      resource = "tag"
    }
    access {
      action = "list"
      resource = "tag"
    }
    kind = "project"
    namespace = "cache"
  }

  permissions {
    access {
      action = "create"
      resource = "artifact"
    }
    access {
      action = "list"
      resource = "artifact"
    }
    access {
      action = "read"
      resource = "artifact"
    }
    access {
      action = "create"
      resource = "artifact-label"
    }
    access {
      action = "create"
      resource = "label"
    }
    access {
      action = "list"
      resource = "label"
    }
    access {
      action = "read"
      resource = "label"
    }
    access {
      action = "list"
      resource = "metadata"
    }
    access {
      action = "read"
      resource = "metadata"
    }
    access {
      action = "read"
      resource = "project"
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
      action = "push"
      resource = "repository"
    }
    access {
      action = "read"
      resource = "repository"
    }
    access {
      action = "update"
      resource = "repository"
    }
    access {
      action = "create"
      resource = "sbom"
    }
    access {
      action = "read"
      resource = "sbom"
    }
    access {
      action = "create"
      resource = "scan"
    }
    access {
      action = "read"
      resource = "scan"
    }
    access {
      action = "create"
      resource = "tag"
    }
    access {
      action = "list"
      resource = "tag"
    }
    kind = "project"
    namespace = "chorus"
  }
  depends_on = [ harbor_project.projects ]
}

# Registries

resource "harbor_registry" "docker_hub" {
  provider_name = "docker-hub"
  name          = "Docker Hub"
  endpoint_url  = "https://hub.docker.com"
}

# Helm charts

resource "null_resource" "push_charts" {
  provisioner "local-exec" {
    quiet = true
    command = <<EOT
    set -e
    chorus_charts_revision=${var.chorus_charts_revision}
    harbor_url=${replace(local.harbor_url, "https://", "")}
    harbor_admin_username=${var.harbor_admin_username}
    harbor_admin_password=${var.harbor_admin_password}

    chmod +x ${path.module}/scripts/push_release_helm_charts.sh && \
    ${path.module}/scripts/push_release_helm_charts.sh $chorus_charts_revision $harbor_url $harbor_admin_username $harbor_admin_password
    EOT
  }
  triggers = {
    always_run = timestamp()
  }
  depends_on = [ harbor_project.projects ]
}

# Container images

# TODO: discuss whether images should be built from scratch
# or if we can previously add (some of) them to a public registry

/*
resource "null_resource" "push_images" {
  provisioner "local-exec" {
    #quiet = true
    command = <<EOT
    set -e

    chmod +x ${path.module}/scripts/push_container_images.sh && \
    ${path.module}/scripts/push_container_images.sh --debug $chorus_images_revision $harbor_url $harbor_admin_username $harbor_admin_password
    EOT
  }
  triggers = {
    always_run = timestamp()
  }
  depends_on = [ harbor_project.projects ]
}
*/

# Outputs

output "argocd_robot_password" {
  value = random_password.argocd_robot_password.result
  description = "Password of the robot user used by ArgoCD"
  sensitive = true
}

output "argoci_robot_password" {
  value = random_password.argoci_robot_password.result
  description = "Password of the robot user used by ArgoCI"
  sensitive = true
}