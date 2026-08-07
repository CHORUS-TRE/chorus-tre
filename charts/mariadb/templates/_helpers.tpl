{{/*
Selector labels matching the pods created by the Bitnami mariadb subchart.
The `chorus-mariadb` prefix avoids collisions with the subchart's own
`mariadb.*` named templates (Helm template names are global).
*/}}
{{- define "chorus-mariadb.selectorLabels" -}}
app.kubernetes.io/name: mariadb
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-mariadb.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{ include "chorus-mariadb.selectorLabels" . }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
