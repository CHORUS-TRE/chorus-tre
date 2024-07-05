# Kube Prometheus Stack

Helm chart wrapping the upstream [kube-prometheus-stack][].


## AlertmanagerConfig

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


<!-- links -->

[Alertmanager]: https://prometheus.io/docs/alerting/latest/alertmanager/
[kube-prometheus-stack]: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
