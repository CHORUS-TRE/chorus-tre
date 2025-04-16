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
