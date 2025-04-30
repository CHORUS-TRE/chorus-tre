variable "valkey_chart_version" {
  description = "Valkey Helm chart version"
  type        = string
}

variable "argo_cd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
}

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