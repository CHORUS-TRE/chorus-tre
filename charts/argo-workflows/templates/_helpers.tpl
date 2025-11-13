{{/*
Get argo-workflows values. Helm doesn't support hyphens.
*/}}
{{- define "argoWorkflows.values" -}}
{{- index .Values "argo-workflows" | toYaml -}}
{{- end -}}
