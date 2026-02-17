# Fluent Operator Helm chart

[Fluent Operator](https://github.com/fluent/fluent-operator/) provides a Kubernetes-native logging pipeline based on Fluent-Bit and Fluentd.

## Required Secrets

### Loki Credentials

You must create a Kubernetes Secret containing the tenant ID as well as the HTTP basic authentication username and password to connect to Loki. The name of this secret is configurable via the Helm values. Default is "loki-credentials".

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: loki-credentials
  namespace: "your-namespace"
stringData:
  httpUser: "your-loki-uer"
  httpPassword: "your-loki-password"
  tenantID: "your-tenant-id"
type: Opaque
```
