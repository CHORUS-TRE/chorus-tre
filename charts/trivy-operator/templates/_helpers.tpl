{{/*
Selector labels for the operator pods. The `chorus-trivy-operator` prefix
avoids collisions with the subchart's own named templates.
*/}}
{{- define "chorus-trivy-operator.selectorLabels" -}}
app.kubernetes.io/name: trivy-operator
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-trivy-operator.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
The CoreDNS-scoped DNS egress rule (reference pattern), reused by both
policy objects when dnsEgress is true.
*/}}
{{- define "chorus-trivy-operator.dnsEgressRule" -}}
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
