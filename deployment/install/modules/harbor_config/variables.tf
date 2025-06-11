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

variable "chorus_charts_revision" {
  description = "Revision of the CHORUS-TRE/chorus-tre repository to get the Helm charts to upload to Harbor"
  type        = string
}

variable "harbor_admin_username" {
  description = "Harbor admin username"
  type        = string
}

variable "harbor_admin_password" {
  description = "Harbor admin password"
  type        = string
  sensitive   = true
}

variable "helm_chart_path" {
  description = "Path to the repository storing the Helm charts"
  type        = string
}