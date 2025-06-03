resource "keycloak_realm" "realm" {
  realm                       = var.realm_name
  organizations_enabled       = true
  default_signature_algorithm = "RS256"
  revoke_refresh_token        = true
  refresh_token_max_reuse     = 0
}

resource "keycloak_openid_client" "openid_client" {
  for_each = var.clients_config

  realm_id            = keycloak_realm.realm.id
  client_id           = each.key
  client_secret       = each.value.client_secret
  enabled             = true
  access_type         = "CONFIDENTIAL"

  root_url = each.value.root_url
  base_url = each.value.base_url
  admin_url = each.value.admin_url
  web_origins = each.value.web_origins
  valid_redirect_uris =each.value.valid_redirect_uris

  standard_flow_enabled = true
  implicit_flow_enabled = true
  direct_access_grants_enabled = true
  frontchannel_logout_enabled = true
}

resource "keycloak_group" "openid_client_group" {
  for_each = var.clients_config

  realm_id = keycloak_realm.realm.id
  name     = each.value.client_group
}

resource "keycloak_openid_client_scope" "openid_client_scope" {
  realm_id               = keycloak_realm.realm.id
  name                   = "groups"
  description            = "When requested, this scope will map a user's group memberships to a claim"
  include_in_token_scope = true
}

resource "keycloak_openid_client_optional_scopes" "client_optional_scopes" {
  for_each = keycloak_openid_client.openid_client

  realm_id  = keycloak_realm.realm.id
  client_id = each.value.id

  optional_scopes = [
    "offline_access",
    "groups"
  ]
}