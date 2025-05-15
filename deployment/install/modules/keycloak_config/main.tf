resource "keycloak_realm" "realm" {
  realm             = var.realm_name
  enabled           = true
}

resource "keycloak_openid_client" "openid_client" {
  realm_id            = keycloak_realm.realm.id
  client_id           = var.client_id
  client_secret       = var.client_secret
  enabled             = true
  access_type         = "CONFIDENTIAL"

  root_url = var.root_url
  base_url = var.base_url
  admin_url = var.admin_url
  web_origins = var.web_origins
  valid_redirect_uris = var.valid_redirect_uris

  standard_flow_enabled = true
  implicit_flow_enabled = true
  direct_access_grants_enabled = true
  frontchannel_logout_enabled = true
}

resource "keycloak_group" "openid_client_group" {
  realm_id = keycloak_realm.realm.id
  name     = var.client_group
}
