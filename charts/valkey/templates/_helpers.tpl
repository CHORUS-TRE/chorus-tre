{{/*
Selector labels matching the pods created by the Bitnami valkey subchart
(primary and replicas; the metrics exporter runs as a sidecar in the same
pods). The `chorus-valkey` prefix avoids collisions with the subchart's own
`valkey.*` named templates.
*/}}
{{- define "chorus-valkey.selectorLabels" -}}
app.kubernetes.io/name: valkey
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-valkey.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
