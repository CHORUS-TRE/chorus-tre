{{/*
Selector labels matching both upstream workloads (the velero server
deployment and the node-agent daemonset — both carry the chart's name and
instance labels and neither is hostNetwork). The `chorus-velero` prefix
avoids collisions with the subchart's own named templates.
*/}}
{{- define "chorus-velero.selectorLabels" -}}
app.kubernetes.io/name: velero
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-velero.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
