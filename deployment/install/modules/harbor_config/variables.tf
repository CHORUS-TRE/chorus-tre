variable "harbor_helm_values_path" {
  description = "Path to the Harbor Helm chart values"
  type        = string
}

variable "argocd_robot_username" {
  description = "Username of the robot to be used by ArgoCD"
  type        = string
}

variable "harbor_projects" {
    description = "List of Harbor projects"
    type = list(string)
}

variable "oidc_endpoint" {
  description = "OIDC server endpoint"
  type        = string
}

variable "oidc_client_id" {
  description = "OIDC client ID"
  type        = string
}

variable "oidc_client_secret" {
  description = "OIDC client secret"
  type        = string
}

variable "oidc_admin_group" {
  description = "OIDC admin group"
  type        = string
}