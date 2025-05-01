variable "cluster_name" {
  description = "The cluster name to be used as a prefix to release names"
  type        = string
}

variable "domain_name" {
  description = "The domain name for your CHORUS-TRE installation"
  type        = string
}

variable "subdomain_name" {
  description = "The subdomain name for your build cluster installation"
  type        = string
}

variable "keycloak_db_chart_version" {
  description = "Keycloak DB Helm chart version (e.g. PostgreSQL)"
  type        = string
}

variable "keycloak_db_helm_chart_path" {
  description = "Path to the Keycloak DB Helm chart (e.g. PostgreSQL)"
  type        = string
}

variable "keycloak_db_helm_values_path" {
  description = "Path to the Keycloak DB Helm chart values (e.g. PostgreSQL)"
  type        = string
}

variable "keycloak_chart_version" {
  description = "Keycloak Helm chart version"
  type        = string
}

variable "keycloak_helm_chart_path" {
  description = "Path to the Keycloak Helm chart"
  type        = string
}

variable "keycloak_helm_values_path" {
  description = "Path to the Keycloak Helm chart values"
  type        = string
}

variable "namespace" {
  description = "Keycloak namespace"
  type        = string
  default     = "keycloak"
}