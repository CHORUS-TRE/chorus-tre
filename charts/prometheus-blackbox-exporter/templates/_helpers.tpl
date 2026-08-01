{{/*
Selector labels matching the upstream chart's exporter pods.
The `chorus-blackbox` prefix avoids collisions with the subchart's own named
templates.
*/}}
{{- define "chorus-blackbox.selectorLabels" -}}
app.kubernetes.io/name: prometheus-blackbox-exporter
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-blackbox.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
