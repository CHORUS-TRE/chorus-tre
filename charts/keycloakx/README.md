# Keycloak (keycloakx)

Helm chart wrapping the upstream [keycloakx][] (aliased as `keycloak`).

Realm import is performed by a chart-owned `keycloak-config-cli` Job
(`templates/keycloak-config-cli-job.yaml`) running as a Helm/Argo PostSync hook.

[keycloakx]: https://github.com/codecentric/helm-charts/tree/master/charts/keycloakx


## Migrating from `charts/keycloak` (bitnami)

- `keycloakConfigCli.*` is top-level here. The bitnami chart nested it under
  `keycloak:` (the subchart alias), so any overrides need to be moved up one
  level — silent fallthrough otherwise.
- Admin and DB credentials are read from `keycloak-secret/adminPassword` and
  `keycloak-db-secret/password`. chorus-tre envs already point at these names;
  consumers porting from stock bitnami defaults (`keycloak-admin-postgres/...`)
  need to rename or recreate.
- Realm and client ConfigMaps are now release-prefixed
  (`<release>-realm-config`, `<release>-client-config`) and consumed only by
  this chart's templates.
- `adminIngress` is gone. For separate admin URL routing, set
  `KC_HOSTNAME_ADMIN` in `keycloak.extraEnv` (Keycloak 26 native).


## Required Secrets

### Client Credentials Secret

A Kubernetes Secret containing the client credentials for the realms. The name is configurable via `.Values.client.existingSecret` (default `keycloak-client-secret`).

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

### Remote State Encryption Secret

Enables remote state in encrypted format. If unset, state is stored in plain.
Generate a key with `openssl rand -hex 32` (must be an **even** number of characters).

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

When moving from an unmanaged keycloak instance, refer to the [keycloak-config-cli normalize docs](https://github.com/adorsys/keycloak-config-cli/blob/main/docs/NORMALIZE.md).
