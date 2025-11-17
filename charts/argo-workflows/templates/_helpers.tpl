{{/*
Get argo-workflows values. Helm does not support hyphens.
*/}}
{{- define "argoWorkflows.values" -}}
{{- index .Values "argo-workflows" | toYaml -}}
{{- end -}}
