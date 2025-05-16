variable "admin_id" {
  description = "Keycloak admin ID"
  type = string
}

variable "realm_name" {
  description = "Keycloak realm name"
  type = string
}

variable "clients_config" {
  description = "Keycloak clients configuration"
  type = map(object({
    client_secret = string
    root_url = string
    base_url = string
    admin_url = string
    web_origins = set(string)
    valid_redirect_uris = set(string)
    client_group = string
  }))
}
