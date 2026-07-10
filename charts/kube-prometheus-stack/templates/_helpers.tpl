{{/*
Common labels for the chorus network-policy objects. The `chorus-kps` prefix
avoids collisions with the upstream chart's named templates.
*/}}
{{- define "chorus-kps.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
The CoreDNS-scoped DNS egress rule (reference pattern), reused by each
component policy when dnsEgress is true.
*/}}
{{- define "chorus-kps.dnsEgressRule" -}}
- to:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: {{ .Values.networkPolicy.dnsNamespace }}
    podSelector:
      matchLabels:
        k8s-app: kube-dns
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: {{ .Values.networkPolicy.dnsNamespace }}
    podSelector:
      matchLabels:
        app: coredns
  ports:
  - protocol: UDP
    port: 53
  - protocol: TCP
    port: 53
{{- end }}
