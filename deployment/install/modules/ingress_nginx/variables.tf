variable "chart_version" {
  description = "Ingress-Nginx Helm chart version"
  type        = string
}

variable "cluster_name" {
  description = "The cluster name to be used as a prefix to release names"
  type        = string
}