terraform {
  required_providers {
    harbor = {
      source = "goharbor/harbor"
      version = "3.10.21"
    }
  }
  # Provider functions require Terraform 1.8 and later.
  required_version = ">= 1.8.0"
}

provider "harbor" {
  url      = var.harbor_url
  username = var.harbor_username
  password = var.harbor_password
}