{{/*
Network policy labels
*/}}
{{- define "networkPolicy.labels" -}}
{{ include "loki.selectorLabels" . }}
{{- if .Values.loki.commonLabels }}
{{ .Values.loki.commonLabels | toYaml }}
{{- end }}
{{- end }}
