{{/*
Selector labels matching the upstream chart's trust-manager pods.
The `chorus-trust-manager` prefix avoids collisions with the subchart's own
named templates.
*/}}
{{- define "chorus-trust-manager.selectorLabels" -}}
app.kubernetes.io/name: trust-manager
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-trust-manager.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
