variable "chart_version" {
  description = "Ingress-Nginx Helm chart version"
  type        = string
}

variable "cluster_name" {
  description = "The cluster name to be used as a prefix to release names"
  type        = string
}

variable "helm_chart_path" {
  description = "Path to the Ingress-Nginx Helm chart"
  type        = string
}

variable "helm_values_path" {
  description = "Path to the Ingress-Nginx Helm chart values"
  type        = string
}
