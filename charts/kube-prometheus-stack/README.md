# Kube Prometheus Stack

Helm chart wrapping the upstream [kube-prometheus-stack][].

## Required Secrets

### AlertmanagerConfig

[Alertmanager][] is configured using a CRD, the configuration is setup to talk
to Webex and needs the following secret in the same namespace.

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: config-webex-secret  # <- alertmanagerConfiguration.webex.credentials.name
data:
  accessToken: <base64 of the access token>  # <- alertmanagerConfiguration.webex.credentials.key
```

Feel free to put the `botID` in the data such that we can trace back to it. To
create a bot visit: <https://developer.webex.com/my-apps/>.

### Loki Credentials

You must create a Kubernetes Secret containing the tenant ID as well as the HTTP basic authentication username and password to connect to Loki. The name of this secret is configurable via the Helm values. Default is "loki-client-credentials".

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: loki-client-credentials
  namespace: "your-namespace"
stringData:
  httpUser: "your-loki-uer"
  httpPassword: "your-loki-password"
  tenantID: "your-tenant-id"
type: Opaque
```


<!-- links -->

[Alertmanager]: https://prometheus.io/docs/alerting/latest/alertmanager/
[kube-prometheus-stack]: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
