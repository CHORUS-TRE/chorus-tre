variable harbor_url {
    description = "Harbor URL"
    type = string
}

variable harbor_username {
    description = "Harbor admin username"
    type = string
}

variable harbor_password {
    description = "Harbor admin password"
    type = string
}

variable "argocd_robot_username" {
  description = "Username of the robot to be used by ArgoCD"
  type        = string
}