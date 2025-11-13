{{/*
Get argo-workflows values. Helm
*/}}
{{- define "argoWorkflows.values" -}}
{{- index .Values "argo-workflows" -}}
{{- end -}}