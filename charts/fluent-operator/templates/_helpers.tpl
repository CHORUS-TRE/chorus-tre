{{/*
Network policy labels
Uses the upstream chart's selector labels
*/}}
{{- define "networkPolicy.labels" -}}
app.kubernetes.io/name: fluent-operator
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Pod selector for fluent-operator pods
*/}}
{{- define "networkPolicy.operatorSelector" -}}
app.kubernetes.io/name: fluent-operator
{{- end }}

{{/*
Pod selector for fluent-bit pods
*/}}
{{- define "networkPolicy.fluentBitSelector" -}}
app.kubernetes.io/name: fluent-bit
{{- end }}

