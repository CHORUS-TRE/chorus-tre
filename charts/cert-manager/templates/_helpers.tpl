{{/*
Selector labels matching every pod of the upstream cert-manager chart
(controller, webhook, cainjector — their name labels differ, but they all
carry the release instance label and nothing else in the namespace does).
The `chorus-cert-manager` prefix avoids collisions with the subchart's own
named templates.
*/}}
{{- define "chorus-cert-manager.selectorLabels" -}}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-cert-manager.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
