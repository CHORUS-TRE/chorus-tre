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