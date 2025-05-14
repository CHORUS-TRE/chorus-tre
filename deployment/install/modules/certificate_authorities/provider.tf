terraform {
  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
      version = "2.36.0"
    }
    helm = {
      source = "hashicorp/helm"
      version = "2.17.0"
    }
    http = {
      source = "registry.terraform.io/hashicorp/http"
      version = "3.5.0"
    }
    time = {
      source = "hashicorp/time"
      version = "0.13.1"
    }
  }
  # Provider functions require Terraform 1.8 and later.
  required_version = ">= 1.8.0"
}