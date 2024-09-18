# Harbor

Helm chart bundling [goharbor/harbor](https://github.com/goharbor/harbor-helm) embracing the HA setup, meaning Postgres and Redis/Valkey are externally managed.

## Known issues

- Authenticated Redis/Valkey is not supported with `helm template`: [harbor-helm#1641](https://github.com/goharbor/harbor-helm/issues/1641)
