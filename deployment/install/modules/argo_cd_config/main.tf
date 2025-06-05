# Read values
locals {
  argocd_values = file("${path.module}/${var.argocd_helm_values_path}")
  argocd_values_parsed = yamldecode(local.argocd_values)
  argocd_namespace = local.argocd_values_parsed.argo-cd.namespaceOverride
  argocd_oidc_secret = "argocd-oidc"
}

resource "kubernetes_secret" "argocd_secret" {
  metadata {
    name = local.argocd_oidc_secret
    namespace = local.argocd_namespace
    labels = {
      "app.kubernetes.io/name" = local.argocd_oidc_secret
      "app.kubernetes.io/part-of" = "argocd"
    }
  }

  data = {
    "keycloak.issuer"        = var.oidc_endpoint
    "keycloak.clientId"      = var.oidc_client_id
    "keycloak.clientSecret"  = var.oidc_client_secret
  }
}

resource "argocd_project" "chorus_build_test" {
  metadata {
    name = var.cluster_name
    namespace = local.argocd_namespace
  }

  spec {
    description = var.cluster_name
    source_repos = [ "*" ]
    destination {
      server    = "https://kubernetes.default.svc"
      name = "in-cluster"
      namespace = "*"
    }
    # TODO: restrict 
    cluster_resource_blacklist {}
    cluster_resource_whitelist {
      group = "*"
      kind  = "*"
    }
    namespace_resource_blacklist {}
    namespace_resource_whitelist {
      group = "*"
      kind = "*"
    }
  }
}


resource "argocd_application_set" "chorus_build_test" {
  metadata {
    name = var.cluster_name
    namespace = local.argocd_namespace
  }

  spec {
    sync_policy {
      preserve_resources_on_deletion = true
    }
    go_template = true
    go_template_options = [ "missingkey=error" ]
    generator {
      git {
        repo_url = var.github_environments_repository_url
        revision = var.github_environments_repository_revision
        file {
          path = "${var.cluster_name}/*/config.json"
        }
      }
    }
    strategy {
      type = "RollingSync"
      rolling_sync {
        step {
          match_expressions {
            key = "stepName"
            operator = "In"
            values = [ "infrastructure" ]
          }
        }
        step {
          match_expressions {
            key = "stepName"
            operator = "In"
            values = [ "database" ]
          }
          max_update = "20%"
        }
        step {
          match_expressions {
            key = "stepName"
            operator = "In"
            values = [ "application" ]
          }
          max_update = "20%"
        }
      }
    }
    template {
      metadata {
        name = "{{index .path.segments 0}}-{{.path.basename}}"
        labels = { 
          stepName = "{{ if hasKey . \"stepName\" }}{{ .stepName }}{{ else }}application{{ end }}"
        }
      }
      spec {
        project = var.cluster_name
        source {
          repo_url = replace(var.helm_chart_repository_url, "https://", "")
          chart = "charts/{{ trimPrefix \"charts/\" .chart }}"
          target_revision = "{{.version}}"
          helm {
            value_files = [ "$values/{{index .path.segments 0}}/{{.path.basename}}/values.yaml" ]
          }
        }
        source {
          repo_url = var.github_environments_repository_url
          target_revision = var.github_environments_repository_revision
          ref = "values"
        }
        destination {
          name = "in-cluster"
          namespace = "{{.namespace}}"
        }
        sync_policy {
          automated {
            prune = true
            self_heal = true
          }
          sync_options = [
            "CreateNamespace=true",
            "preserveResourcesOnDeletion=true",
            "ServerSideApply={{if hasKey . \"serverSideApply\" }}{{ .serverSideApply }}{{ else }}false{{ end }}"
          ]
        }
      }
    }
  }
  depends_on = [ argocd_project.chorus_build_test ]
}
