# Fluent Operator Helm chart

[Fluent Operator](https://github.com/fluent/fluent-operator/) provides a Kubernetes-native logging pipeline based on Fluent-Bit and Fluentd.

## Required Secrets

### Loki Bearer Token

You must create a Kubernetes Secret containing the bearer token to connect to Loki. The name of this secret is configurable via the Helm value `.Values.fluent-operator.fluentbit.output.loki.bearerToken.valueFrom.secretKeyRef.name`. Default is "loki-bearer-token".

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: loki-bearer-token
stringData:
  token: "your-bearer-token"
type: Opaque
```

### Registry Credentials

If not created automatically (e.g. by [reflector](https://github.com/emberstack/kubernetes-reflector)), you must create a secret to store credentials to pull images from Harbor.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: regcred
data:
  .dockerconfigjson: <your-docker-config-json-in-base64>
type: kubernetes.io/dockerconfigjson
```
