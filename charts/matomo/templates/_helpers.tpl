{{/*
Selector labels matching every pod of the Bitnami matomo subchart (web
deployment and the archive / task-scheduler cronjob pods). The
`chorus-matomo` prefix avoids collisions with the subchart's own named
templates.
*/}}
{{- define "chorus-matomo.selectorLabels" -}}
app.kubernetes.io/name: matomo
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-matomo.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
