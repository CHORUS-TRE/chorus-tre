/*
The values declared in this file follow
the CHORUS-specific versioning as specified
in https://github.com/CHORUS-TRE/chorus-tre/tree/master/charts

Use the scripts/init_helm_charts.sh
script to populate the default version automatically
as described in the readme

The variabes names below correspond to their related
Helm chart with the dashes "-" replaced by
underscores "_" and with "_version" appended
*/

variable "ingress_nginx_version" {
  description = "Ingress-Nginx Helm chart version"
  type        = string
  default     = "x.x.x"
}

variable "cert_manager_version" {
  description = "Cert-Manager Helm chart version"
  type        = string
  default     = "x.x.x"
}

variable "valkey_version" {
  description = "Valkey Helm chart version"
  type        = string
  default     = "x.x.x"
}

variable "argo_cd_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "x.x.x"
}