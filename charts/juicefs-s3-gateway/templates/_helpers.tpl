{{/*
Selector labels matching the upstream chart's gateway pods.
The `chorus-juicefs-s3-gateway` prefix avoids collisions with the subchart's
own named templates.
*/}}
{{- define "chorus-juicefs-s3-gateway.selectorLabels" -}}
app.kubernetes.io/name: juicefs-s3-gateway
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-juicefs-s3-gateway.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
