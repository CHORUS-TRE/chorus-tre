variable "argocd_cache_chart_version" {
  description = "ArgoCD cache Helm chart version (e.g. Valkey)"
  type        = string
}

variable "argocd_chart_version" {
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

variable "argocd_cache_helm_chart_path" {
  description = "Path to the ArgoCD cache Helm chart (e.g. Valkey)"
  type        = string
}

variable "argocd_cache_helm_values_path" {
  description = "Path to the ArgoCD cache Helm chart values (e.g. Valkey)"
  type        = string
}

variable "argocd_helm_chart_path" {
  description = "Path to the ArgoCD Helm chart"
  type        = string
}

variable "argocd_helm_values_path" {
  description = "Path to the ArgoCD Helm chart values"
  type        = string
}

variable "namespace" {
  description = "ArgoCD namespace"
  type        = string
  default     = "argocd"
}