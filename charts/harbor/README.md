# Harbor

Helm chart bundling [goharbor/harbor](https://github.com/goharbor/harbor-helm) embracing the HA setup, meaning Postgres and Redis/Valkey are externally managed.

## Known issues

- Authenticated Redis/Valkey is not supported with `helm template`: [harbor-helm#1641](https://github.com/goharbor/harbor-helm/issues/1641)


## Mandatory secrets

### Harbor Robot Secrets

The configuration job requires one Kubernetes secret per robot account. Each robot defined in `values.yaml` under the `robots` section must have a corresponding secret.

The secret name format is: `<prefix><robot-name>` where:
- **prefix**: Defined by `configJob.robotSecretPrefix` in `values.yaml` (default: `harbor-robot-`)
- **robot-name**: The robot name from the `robots` list (e.g., `chorus-local`, `chorus-build`)

Each secret must contain a key named `secret` with the robot account password as its value.

Example for robot `chorus-local`:
```bash
kubectl create secret generic harbor-robot-chorus-local \
  --from-literal=secret='your-secret-here' \
  -n <namespace>
```

Or using a secret manifest:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: harbor-robot-chorus-local
  namespace: <namespace>
type: Opaque
stringData:
  secret: "your-secret-here"
```
