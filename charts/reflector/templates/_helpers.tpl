{{/*
Selector labels matching the upstream chart's reflector pods.
The `chorus-reflector` prefix avoids collisions with the subchart's own named
templates.
*/}}
{{- define "chorus-reflector.selectorLabels" -}}
app.kubernetes.io/name: reflector
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-reflector.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
