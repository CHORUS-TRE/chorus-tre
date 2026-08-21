{{/*
Selector labels matching the pods created by the Bitnami postgresql subchart.
The `chorus-postgresql` prefix avoids collisions with the subchart's own
`postgresql.*` named templates (Helm template names are global).
*/}}
{{- define "chorus-postgresql.selectorLabels" -}}
app.kubernetes.io/name: postgresql
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-postgresql.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "chorus-postgresql.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
