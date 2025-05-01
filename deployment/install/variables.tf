variable "cluster_name" {
  description = "The cluster name to be used as a prefix to release names"
  type        = string
}

variable "kubeconfig_path" {
  description = "Path to the Kubernetes config file"
  type        = string
}

variable "kubeconfig_context" {
  description = "Kubernetes context to use"
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

variable "helm_chart_path" {
  description = "Path to the repository storing the Helm charts"
  type        = string
  default     = "../../charts"
}

variable "helm_values_path" {
  description = "Path to the repository storing the Helm chart values"
  type        = string
  default     = "../../../environment-template/chorus-build"
}