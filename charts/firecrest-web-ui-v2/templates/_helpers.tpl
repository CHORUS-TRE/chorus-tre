{{/*
Selector labels matching the upstream chart's pods (fixed `app` label; the
upstream chart hardcodes its object names and labels, one instance per
namespace by construction). The `chorus-firecrest-web-ui-v2` prefix avoids
collisions with the subchart's own named templates.
*/}}
{{- define "chorus-firecrest-web-ui-v2.selectorLabels" -}}
app: firecrest-web-ui
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-firecrest-web-ui-v2.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
