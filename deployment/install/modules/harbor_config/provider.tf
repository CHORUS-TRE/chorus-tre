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