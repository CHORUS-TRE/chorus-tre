variable "cert_manager_chart_version" {
  description = "Cert-Manager Helm chart version"
  type        = string
}

variable "selfsigned_chart_version" {
  description = "Self-Signed Issuer Helm chart version"
  type        = string
}

variable "cert_manager_app_version" {
  description = "Cert-Manager version"
  type        = string
}

variable "cluster_name" {
  description = "The cluster name to be used as a prefix to release names"
  type        = string
}

variable "cert_manager_helm_chart_path" {
  description = "Path to the Cert-Manager Helm chart"
  type        = string
}

variable "cert_manager_helm_values_path" {
  description = "Path to the Cert-Manager Helm chart values"
  type        = string
}

variable "selfsigned_helm_chart_path" {
  description = "Path to the Self-Signed Issuer Helm chart"
  type        = string
}

variable "selfsigned_helm_values_path" {
  description = "Path to the Self-Signed Issuer Helm chart values"
  type        = string
}