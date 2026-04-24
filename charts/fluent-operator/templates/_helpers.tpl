{{/*
Network policy labels
Uses the upstream chart's selector labels
*/}}
{{- define "networkPolicy.labels" -}}
app.kubernetes.io/name: fluent-operator
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

