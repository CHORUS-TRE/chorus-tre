/*
Do not add Kubernetes/Helm related values in this file.
Instead, build upon the environment-template repository
https://github.com/CHORUS-TRE/environment-template
and reference it using the "helm_values_path" variable below
*/

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

variable "github_environments_repository_pat" {
  description = "Fine-grained personal access token (PAT) to access the environments repository"
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

variable "ingress_nginx_chart_name" {
  description = "Ingress-Nginx Helm chart folder name"
  type        = string
  default     = "ingress-nginx"
}

variable "cert_manager_chart_name" {
  description = "Cert-Manager Helm chart folder name"
  type        = string
  default     = "cert-manager"
}

variable "selfsigned_chart_name" {
  description = "Self-Signed Issuer Helm chart folder name"
  type        = string
  default     = "self-signed-issuer"
}

variable "argocd_chart_name" {
  description = "ArgoCD Helm chart folder name"
  type        = string
  default     = "argo-cd"
}

variable "valkey_chart_name" {
  description = "Valkey Helm chart folder name"
  type        = string
  default     = "valkey"
}

variable "keycloak_chart_name" {
  description = "Keycloak Helm chart folder name"
  type        = string
  default     = "keycloak"
}

variable "postgresql_chart_name" {
  description = "PostgreSQL Helm chart folder name"
  type        = string
  default     = "postgresql"
}

variable "harbor_chart_name" {
  description = "Harbor Helm chart folder name"
  type        = string
  default     = "harbor"
}

variable "github_environments_repository_url" {
  description = "URL of the environments repository"
  type        = string
  default     = "https://github.com/CHORUS-TRE/environments"
}

variable "github_environments_repository_secret" {
  description = "Secret to store the GitHub credentials in for ArgoCD"
  type        = string
  default     = "argo-cd-github-environments"
}

variable "argocd_harbor_robot_username" {
  description = "Harbor robot username used by ArgoCD"
  type        = string
  default     = "argo-cd"
}