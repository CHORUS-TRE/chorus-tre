terraform {
  required_providers {
    keycloak = {
      source = "keycloak/keycloak"
      version = "5.2.0"
    }
  }
  # Provider functions require Terraform 1.8 and later.
  required_version = ">= 1.8.0"
}
