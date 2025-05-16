variable "argocd_helm_values_path" {
  description = "Path to the ArgoCD Helm chart values"
  type        = string
}

variable "app_project_path" {
  description = "Path to the ArgoCD AppProject manifest"
  type        = string
}

variable "application_set_path" {
  description = "Path to the ArgoCD ApplicationSet manifest"
  type        = string
}

variable "oidc_endpoint" {
  description = "OIDC server endpoint"
  type        = string
}

variable "oidc_client_id" {
  description = "OIDC client ID"
  type        = string
}

variable "oidc_client_secret" {
  description = "OIDC client secret"
  type        = string
}