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

variable "github_environments_repository_pat" {
  description = "Fine-grained personal access token (PAT) to access the environments repository"
  type        = string
}

variable "github_environments_repository_secret" {
  description = "Secret to store the GitHub credentials in"
  type        = string
}

variable "github_environments_repository_url" {
  description = "URL of the environments repository"
  type        = string
}

variable "harbor_robot_username" {
  description = "Username of the robot used to connect to Harbor"
  type        = string
}

variable "harbor_robot_password" {
  description = "Password of the robot used to connect to Harbor"
  type        = string
}