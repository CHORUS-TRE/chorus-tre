# Keycloak

So you've got yourself a Keycloak and have to do the heavy setup. This is the right time for you to shine and this guide will help you do so.

The goal is to **NOT** manage users directly inside Keycloak but grant them accesses to what they are allowed to access. To do so, we'll link one or more external Identity Providers, create the Clients for our applications, and put Users into proper groups.

## Identity providers

For **chorus-build** we've got:

- Google <https://console.cloud.google.com/welcome?project=chorus-build-434507>

And for chorus-dev:

- Google <https://console.cloud.google.com/welcome?project=chorus-dev-437408>

Feel free to add more, even enable anything that the CHUV, EBRAINS, or else can provide.

## Applications with SSO

This is for the _build_ environment, as the _chorus-backend_ is also using Keycloak extra _realms_ will be needed.

Each environment has a realm called after itself, e.g. `build` for _chorus-build_.

### ArgoCD

The OIDC setup for ArgoCD is done via the _cm_ (ConfigMap) under the `oidc.config` key, as well as the _rbac_ under the `policy.csv` key.

The OIDC configuration needs to provide the issuer (the realm address), the clientId, and the clientSecret which points to ...

The RBAC configuration maps the Keycloak _group_ call `ArgoCDAdmins` to the ArgoCD role `admin`.

```yaml
argo-cd:
  configs:
    cm:
      admin.enabled: true
      # See: https://argo-cd.readthedocs.io/en/stable/operator-manual/user-management/keycloak/
      oidc.config: |
        name: Keycloak
        issuer: https://auth.build.chorus-tre.ch/realms/build
        clientId: argocd
        clientSecret: $oidc.keycloak.clientSecret
        requestedScopes: [openid, profile, email, groups]
    rbac:
      policy.csv: |-
        g, ArgoCDAdmins, role:admin
```

### Argo Workflows

Argo Workflows setup is a bit harder as it requires to fiddle around with _ServiceAccount_. Go read [the documentation first](https://argo-workflows.readthedocs.io/en/stable/argo-server-sso/).

The SSO configuration assumes that the client ID and Secret are stored into a secret. It needs to be enabled in the `authModes` list beforehand.

```yaml
argo-workflows:
  server:
    authModes:
      - client
      - sso

    sso:
      enabled: true
      issuer: https://auth.build.chorus-tre.ch/realms/build
      clientId:
        name: secretName
        key: clientId
      clientSecret:
        name: secretName
        key: clientSecret
      redirectUrl: https://argo-workflows.build.chorus-tre.ch/oauth2/callback
      rbac:
        enabled: true
      scopes: [openid, profile, email, groups]
```

The `argo-workflow` ServiceAccount in **the same namespace** as the Argo Workflows server has the following annotations.

```yaml
metadata:
  name: argo-workflow
  namespace: kube-system
  annotations:
    workflows.argoproj.io/rbac-rule: "'ArgoCIAdmins' in groups"
    workflows.argoproj.io/rbac-rule-precedence: "1"
```

Which means that the Keycloak group called 'ArgoCIAdmins' links yourself with this service account. In case of doubt, the following command shows the actual rights of the above ServiceAccount.

```yaml
kubectl auth can-i --list \
--as=system:serviceaccount:kube-system:argo-workflow
```

### Kube-prometheus-stack

The Kube-prometheus-stack has two use cases: Grafana, and the rest. Grafana can handle OIDC, just like the applications described above, however Prometheus or Alertmanager don't. In that case, the authentication process is handled by [oauth2-proxy][] with extra annotations on the Ingress.

#### Grafana

Grafana comes with a [great documentation](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/keycloak/). The hard part concerns the _roles_. The easiest way is to create Role at the Client scope named `admin` and `editor`, and have people from certain groups inherit from them.

```yaml
grafana:
  envValueFrom:
    GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET:
      secretKeyRef:
        name: grafana-secret
        key: oauth-client-secret

  grafana.ini:
    auth.generic_oauth:
      enabled: true
      name: Keycloak
      allow_sign_up: true
      client_id: grafana
      #client_secret is coming from the above envValueFrom
      email_attribute_path: email
      login_attribute_path: username
      name_attribute_path: full_name
      auth_url: https://auth.build.chorus-tre.ch/realms/build/protocol/openid-connect/auth?kc_idp_hint=google
      token_url: https://auth.build.chorus-tre.ch/realms/build/protocol/openid-connect/token
      api_url: https://auth.build.chorus-tre.ch/realms/build/protocol/openid-connect/userinfo
      role_attribute_path: contains(roles[*], 'admin') && 'Admin' || contains(roles[*], 'editor') && 'Editor' || 'Viewer'
      allow_assign_grafana_admin: true
```

#### Prometheus/Alertmanager

The [oauth2-proxy documentation](https://oauth2-proxy.github.io/oauth2-proxy/configuration/providers/keycloak_oidc/) is a good starting point to understand what follows. So far, no roles are configured to keep it as simple as possible.

In both ingresses, it's required to enforce the authentication via the following annotations.

```yaml
annotations:
  nginx.ingress.kubernetes.io/auth-url: "https://$host/oauth2/auth"
  nginx.ingress.kubernetes.io/auth-signin: "https://$host/oauth2/start?rd=$escaped_request_uri"
```

And then, each service gets its oauth2-proxy using the _redis_ session storage. The _cookie_ only session storage cannot be used as Keycloak is creating big JWTs.

Oauth2-proxy needs a secret with the following items.

```yaml
dataString:
  cookie-secret: $(openssl rand -base64 32 | head -c 32 | base64)
  client-secert: from keycloak
  client-id: from keycloak
```

You may reuse the same clientId for both as the redirectUrl is part of the configuration.

## Other environments

Ideally, the real environments, aka **dev**, **qa**, etc. are fully decorrelated from the build one. However, they fairly similar.

The **dev** environments also have the following services deployed that are linked with Keycloak:

- Harbor
- Kube-prometheus-stack (Grafana, Prometheus, AlertManager)

Their setup are almost the same as the ones in build.

### Chorus-backend

TODO(@sami-sweng): how is Keycloak setup for the chorus-backend.
