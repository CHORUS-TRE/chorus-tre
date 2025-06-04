variable "argocd_helm_values_path" {
  description = "Path to the ArgoCD Helm chart values"
  type        = string
}

variable "cluster_name" {
  description = "The cluster name to be used as a prefix to release names"
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

variable "github_environments_repository_url" {
  description = "URL of the environments repository"
  type        = string
}

variable "github_environments_repository_revision" {
  description = "Revision of the environments repository"
  type        = string
}

variable "helm_chart_repository_url" {
  description = "URL of the Helm chart repository"
  type        = string
}