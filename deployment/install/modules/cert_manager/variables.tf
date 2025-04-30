variable "chart_version" {
  description = "Cert-Manager Helm chart version"
  type        = string
}

variable "crds_version" {
  description = "Cert-Manager CRDs version"
  type        = string
}

variable "cluster_name" {
  description = "The cluster name to be used as a prefix to release names"
  type        = string
}