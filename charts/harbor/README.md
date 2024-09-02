# Harbor

Helm chart wrapping the upstream [habor](https://github.com/bitnami/charts/tree/main/bitnami/harbor).
It expects a secret in the format below to exist.

```
apiVersion: v1
kind: Secret
metadata:
  name: harbor-secret-vars
  namespace: harbor
type: Opaque
stringData:
  HARBOR_ADMIN_PASSWORD: "ch@ngeme1"
  HARBOR_DATABASE_PASSWORD: "ch@ngeme2"
  POSTGRESQL_PASSWORD: "ch@ngeme2" #same as above
  postgres-password: "ch@ngeme2" #same as above
  REGISTRY_CREDENTIAL_USERNAME: "ch@ngeme3"
  REGISTRY_CREDENTIAL_PASSWORD: "ch@ngeme4"
  REGISTRY_HTPASSWD: "generate via htpasswd -nbBC10 "ch@ngeme3" "ch@ngeme4"
  # The REDIS default URLs are required here because Bitnami. More information from https://github.com/bitnami/charts/tree/main/bitnami/harbor
  _REDIS_URL_CORE: "redis://harbor-redis-master:6379/0"
  _REDIS_URL_REG: "redis://harbor-redis-master:6379/2"
  SCANNER_REDIS_URL: "redis://harbor-redis-master:6379/5"
  SCANNER_STORE_REDIS_URL: "redis://harbor-redis-master:6379/5"
  SCANNER_JOB_QUEUE_REDIS_URL: "redis://harbor-redis-master:6379/5"
  JOB_SERVICE_POOL_REDIS_URL: "redis://harbor-redis-master:6379/1"
```