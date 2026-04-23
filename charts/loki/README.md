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

## Network Policies

**Important:** This wrapper chart defines custom NetworkPolicy resources that are **not present in the upstream Loki chart**. These policies are maintained locally to provide granular network security for Loki deployments.

### Overview

- **Deployment Mode:** Designed for `Distributed` mode only
- **Flavors:** Supports both `kubernetes` and `cilium` NetworkPolicy types
- **Configuration:** Set `networkPolicy.enabled: true` and `networkPolicy.flavor: kubernetes` or `cilium`

### Allowed Communication Flows

```mermaid
graph LR
    subgraph fluent["fluent namespace"]
        FluentBit[Fluent Bit]
    end

    subgraph prometheus["prometheus namespace"]
        Grafana[Grafana]
        Prometheus[Prometheus]
    end

    subgraph loki["loki namespace"]
        Gateway[Loki Gateway<br/>nginx]
        LokiPods["All Loki Components<br/>(Distributor, Ingester,<br/>Querier, Compactor,<br/>Index Gateway, etc.)"]

        Gateway -->|"internal"| LokiPods
    end

    subgraph kube-system["kube-system namespace"]
        CoreDNS[CoreDNS]
    end

    S3[S3 Storage<br/>external]

    FluentBit -->|"http<br/>(logs)"| Gateway
    Grafana -->|"http<br/>(queries)"| Gateway
    Prometheus -->|"http-metrics<br/>(scraping)"| Gateway
    Prometheus -->|"http-metrics<br/>(scraping)"| LokiPods

    Gateway -->|"DNS:53"| CoreDNS
    LokiPods -->|"DNS:53"| CoreDNS

    Gateway -->|"HTTPS:443"| S3
    LokiPods -->|"HTTPS:443"| S3

    classDef fluentStyle fill:#e1f5ff,stroke:#01579b,stroke-width:2px
    classDef prometheusStyle fill:#fff3e0,stroke:#e65100,stroke-width:2px
    classDef lokiStyle fill:#f3e5f5,stroke:#4a148c,stroke-width:2px
    classDef systemStyle fill:#e8f5e9,stroke:#1b5e20,stroke-width:2px
    classDef infraStyle fill:#f5f5f5,stroke:#616161,stroke-width:2px

    class FluentBit fluentStyle
    class Grafana,Prometheus prometheusStyle
    class Gateway,LokiPods lokiStyle
    class CoreDNS systemStyle
    class S3 infraStyle
```

### Policies Created

#### Ingress Policies
- **loki-ingress**: Allows Fluent Bit (fluent ns) and Grafana (prometheus ns) → Gateway (http)
- **loki-ingress-metrics**: Allows Prometheus (prometheus ns) → All Loki pods (http-metrics)
- **loki-namespace-only**: Allows all Loki pods to communicate within same namespace

#### Egress Policies
- **loki-egress-dns**: Allows all Loki pods → CoreDNS (kube-system:53)
- **loki-egress-external-storage**: Allows all Loki pods → S3 storage (HTTPS:443)
- **loki-namespace-only**: Allows all Loki pods to communicate within same namespace

### Configuration

```yaml
networkPolicy:
  enabled: true
  flavor: cilium  # or "kubernetes"
  kubePrometheusStack:
    namespace: prometheus
  fluentBit:
    namespace: fluent
  externalStorage:
    cidrs: []  # Add your S3 provider's CIDR ranges here
```
