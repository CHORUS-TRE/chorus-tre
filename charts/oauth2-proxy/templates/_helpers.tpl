{{/*
Selector labels matching the upstream chart's oauth2-proxy pods.
The `chorus-oauth2-proxy` prefix avoids collisions with the subchart's own
named templates.
*/}}
{{- define "chorus-oauth2-proxy.selectorLabels" -}}
app.kubernetes.io/name: oauth2-proxy
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-oauth2-proxy.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
