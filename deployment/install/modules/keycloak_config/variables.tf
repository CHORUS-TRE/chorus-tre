variable "admin_id" {
  description = "Keycloak admin ID"
  type = string
}

variable realm_name {
  description = "Keycloak realm name"
  type = string
}

variable "client_id" {
  description = "OIDC client ID"
  type = string
}

variable "client_secret" {
  description = "OIDC client secret"
  type = string
}

variable root_url {
  description = "OIDC client root URL appended to relative URLs"
  type = string
}

variable base_url {
  description = "OIDC client base URL or home URL for the auth server to redirect to"
  type = string
}

variable admin_url {
  description = "OIDC client admin interface URL"
  type = string
}

variable "web_origins" {
  description = "OIDCclient allowed CORS origins"
  type = list(string)
}

variable "valid_redirect_uris" {
  description = "OIDC client valid URI pattern a browser can redirect to after a successful login"
  type = list(string)
}

variable "client_group" {
  description = "OIDC client group"
  type = string
}