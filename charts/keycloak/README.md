# Keycloak

This bundles the [keycloak chart][] with an option to put a certificate from cert-manager in order to secure the Ingress <-> Keycloak communication channel.

[keycloak chart]: https://github.com/bitnami/charts/tree/main/bitnami/keycloak


## Required Secrets

### Client Credentials Secret

You must create a Kubernetes Secret containing the client credentials for the realms. The name of this secret is configurable via the Helm value `.Values.client.existingSecret`. Default is "keycloak-client-secret".

**Build cluster secret example**

Realms: master and infra
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-client-secret
stringData:
  GOOGLE_CLIENT_ID: "my-google-client-id"
  GOOGLE_CLIENT_SECRET: "my-google-client-secret"
  ALERTMANAGER_CLIENT_SECRET: "my-alertmanager-secret"
  ARGO_CD_CLIENT_SECRET: "my-argo-cd-secret"
  ARGO_WORKFLOWS_CLIENT_SECRET: "my-argo-workflows-secret"
  GRAFANA_CLIENT_SECRET: "my-grafana-secret"
  HARBOR_CLIENT_SECRET: "my-harbor-secret"
  PROMETHEUS_CLIENT_SECRET: "my-prometheus-secret"
type: Opaque
```

**Remote cluster secret example**

Realms: master, infra and chorus
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-client-secret
stringData:
  GOOGLE_CLIENT_ID: "my-google-client-id"
  GOOGLE_CLIENT_SECRET: "my-google-client-secret"
  ALERTMANAGER_CLIENT_SECRET: "my-alertmanager-secret"
  GRAFANA_CLIENT_SECRET: "my-grafana-secret"
  HARBOR_CLIENT_SECRET: "my-harbor-secret"
  MATOMO_CLIENT_SECRET: "my-matomo-secret"
  PROMETHEUS_CLIENT_SECRET: "my-prometheus-secret"
  CHORUS_CLIENT_SECRET: "my-chorus-client-secret"
type: Opaque
```

This secret is referenced in the chart values and is required for Keycloak to configure client secrets for the various realms.

### Remote State Encryption Secret

Enables remote state in encrypted format.
If unset, state will be stored in plain.
You can generate a key with ```openssl rand -hex 32```.
Make sure to use an **even** number of characters.

Example:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-remotestate-encryption-key
stringData:
  encryptionKey: "change-me"
type: Opaque
```

## Keycloak realm normalization

When moving from "unmanaged" keycloak instance, please refer to the [keycloak-config-cli documentation](https://github.com/adorsys/keycloak-config-cli/blob/main/docs/NORMALIZE.md).
