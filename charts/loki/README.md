# Loki Helm Chart

Helm chart for Grafana Loki and Grafana Enterprise Logs supporting monolithic, simple scalable, and microservices modes.

## DNS setting

Make sure to configure Loki to use the correct DNS setting for your cluster.
You can check which DNS service you have by running:

```
kubectl get svc --namespace=kube-system -l k8s-app=kube-dns  -o jsonpath='{.items..metadata.name}'
```

```
loki:
  global:
     dnsService: "your-dns-setting-name"
```

## Mandatory Secrets

### Loki Clients Basic Auth

Create a ```.htpasswd``` file

```
htpasswd -bc .htpasswd chorus-fluentbit <chorus-fluentbit-password>
htpasswd -b .htpasswd chorus-grafana  <chorus-grafana-password>
```

Create a Kubernetes secret containing the ```.htpasswd``` file.
You can change the secret name in the Helm chart values.
Default is loki-gateway-htpasswd.

```
kubectl create secret generic loki-gateway-htpasswd -n <namespace> --from-file=.htpasswd
```

The secret should look similar to:

```
apiVersion: v1
data:
  .htpasswd: <base64-encoded-content>
kind: Secret
metadata:
  name: loki-gateway-htpasswd
  namespace: <namespace>
```

Finally, delete your local ```.htpasswd``` file.

```
rm .htpasswd
```

### S3 Credentials

You can change the secret name in the Helm chart values.
Default is loki-s3-credentials.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: loki-s3-credentials
  namespace: <namespace>
stringData:
  accessKeyId: "my-s3-access-key-id"
  secretAccessKey: "my-s3-secret-access-key"
type: Opaque
```
