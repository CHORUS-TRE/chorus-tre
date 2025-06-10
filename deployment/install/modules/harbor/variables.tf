variable "cluster_name" {
  description = "The cluster name to be used as a prefix to release names"
  type        = string
}

variable "harbor_chart_version" {
  description = "Harbor Helm chart version"
  type        = string
}

variable "harbor_db_chart_version" {
  description = "Harbor DB Helm chart version (e.g. PostgreSQL)"
  type        = string
}

variable "harbor_cache_chart_version" {
  description = "Harbor cache Helm chart version (e.g. Valkey)"
  type        = string
}

variable "harbor_helm_chart_path" {
  description = "Path to the Harbor Helm chart"
  type        = string
}

variable "harbor_db_helm_chart_path" {
  description = "Path to the Harbor DB Helm chart (e.g. PostgreSQL)"
  type        = string
}

variable "harbor_cache_helm_chart_path" {
  description = "Path to the Harbor cache Helm chart (e.g. Valkey)"
  type        = string
}

variable "harbor_helm_values_path" {
  description = "Path to the Harbor Helm chart values"
  type        = string
}

variable "harbor_db_helm_values_path" {
  description = "Path to the Harbor DB Helm chart values (e.g. PostgreSQL)"
  type        = string
}

variable "harbor_cache_helm_values_path" {
  description = "Path to the Harbor cache Helm chart values (e.g. Valkey)"
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

variable "oidc_admin_group" {
  description = "OIDC admin group"
  type        = string
}

variable "harbor_admin_username" {
  description = "Harbor admin username"
  type        = string
}