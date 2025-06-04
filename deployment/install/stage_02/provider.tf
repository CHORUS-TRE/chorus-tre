terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.36.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.17.0"
    }
    http = {
      source  = "registry.terraform.io/hashicorp/http"
      version = "3.5.0"
    }
    random = {
      source  = "registry.terraform.io/hashicorp/random"
      version = "3.7.2"
    }
    harbor = {
      source  = "goharbor/harbor"
      version = "3.10.21"
    }
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.2.0"
    }
    argocd = {
      source  = "argoproj-labs/argocd"
      version = "7.8.2"
    }
  }
  # Provider functions require Terraform 1.8 and later.
  required_version = ">= 1.8.0"
}

provider "kubernetes" {
  config_path    = var.kubeconfig_path
  config_context = var.kubeconfig_context
}

provider "helm" {
  kubernetes {
    config_path    = var.kubeconfig_path
    config_context = var.kubeconfig_context
  }
}
