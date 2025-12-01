# Keycloak

This bundles the [keycloak chart][] with an option to put a certificate from cert-manager in order to secure the Ingress <-> Keycloak communication channel.

[keycloak chart]: https://github.com/bitnami/charts/tree/main/bitnami/keycloak


## Required Secret for Client Credentials

You must create a Kubernetes Secret containing the client credentials for the realms. The name of this secret is configurable via the Helm value `.Values.client.existingSecret`. Default is "keycloak-client-secret".

Example:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-client-secret
stringData:
  # master and infra realm
  GOOGLE_CLIENT_ID: "my-google-client-id"
  GOOGLE_CLIENT_SECRET: "my-google-client-secret"
  # infra realm only
  ALERTMANAGER_CLIENT_SECRET: "my-alertmanager-secret"
  GRAFANA_CLIENT_SECRET: "my-grafana-secret"
  HARBOR_CLIENT_SECRET: "my-harbor-secret"
  MATOMO_CLIENT_SECRET: "my-matomo-secret"
  PROMETHEUS_CLIENT_SECRET: "my-prometheus-secret"
  # chorus realm only
  CHORUS_CLIENT_SECRET: "my-chorus-client-secret"
type: Opaque
```

This secret is referenced in the chart values and is required for Keycloak to configure client secrets for the various realms.

## Keycloak realm normalization

When moving from "unmanaged" keycloak instance, please refer to the [keycloak-config-cli documentation](https://github.com/adorsys/keycloak-config-cli/blob/main/docs/NORMALIZE.md).
