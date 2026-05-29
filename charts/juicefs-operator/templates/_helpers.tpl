{{/*
Common labels and the values used by the workload templates (CronSync + GC).
*/}}

{{- define "juicefs-operator.labels" -}}
app.kubernetes.io/name: juicefs-operator
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
{{- end -}}

{{- define "juicefs-operator.cronSyncName" -}}
juicefs-data-replica
{{- end -}}
