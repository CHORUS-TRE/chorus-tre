variable "harbor_helm_values_path" {
  description = "Path to the Harbor Helm chart values"
  type        = string
}

variable "argocd_robot_username" {
  description = "Username of the robot to be used by ArgoCD"
  type        = string
}

variable "argoci_robot_username" {
  description = "Username of the robot to be used by ArgoCI"
  type        = string
}