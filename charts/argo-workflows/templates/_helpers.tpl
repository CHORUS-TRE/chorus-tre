{{/*
Get argo-workflows values. Helm does not support hyphens.
*/}}
{{- define "argoWorkflows.values" -}}
{{- index .Values "argo-workflows" | toYaml -}}
{{- end -}}

{{/*
Selector labels matching both upstream deployments (workflow-controller and
server — they share the static part-of label; instance scoping keeps the
policy release-local). Workflow step pods run in the configured
workflowNamespaces and are out of this chart's scope. The
`chorus-argo-workflows` prefix avoids collisions with the subchart's own
named templates.
*/}}
{{- define "chorus-argo-workflows.selectorLabels" -}}
app.kubernetes.io/part-of: argo-workflows
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels for the chorus network-policy objects.
*/}}
{{- define "chorus-argo-workflows.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
