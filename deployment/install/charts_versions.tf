/*
All the variables declared in this file follow
the CHORUS-specific versioning as specified
in https://github.com/CHORUS-TRE/chorus-tre/tree/master/charts
*/

variable "ingress_nginx_version" {
  description = "Ingress-Nginx Helm chart version"
  type        = string
  default     = "0.0.4"
}

variable "cert_manager_version" {
  description = "Cert-Manager Helm chart version"
  type        = string
  default     = "0.0.10"
}

variable "valkey_version" {
  description = "Valkey Helm chart version"
  type        = string
  default     = "0.0.8"
}

variable "argocd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "0.0.30"
}