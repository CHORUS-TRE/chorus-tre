variable "chart_version" {
  description = "Cert-Manager Helm chart version"
  type        = string
}

variable "app_version" {
  description = "Cert-Manager version"
  type        = string
}

variable "cluster_name" {
  description = "The cluster name to be used as a prefix to release names"
  type        = string
}

variable "helm_chart_path" {
  description = "Path to the Cert-Manager Helm chart"
  type        = string
}

variable "helm_values_path" {
  description = "Path to the Cert-Manager Helm chart values"
  type        = string
}
