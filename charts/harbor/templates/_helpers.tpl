{{/*
Selector labels matching every pod of the goharbor subchart (core, portal,
registry, jobservice, trivy, exporter, nginx, internal db/redis when enabled —
they all carry the goharbor-style `app: harbor` label). The `chorus-harbor`
prefix avoids collisions with the subchart's own `harbor.*` named templates.
*/}}
{{- define "chorus-harbor.selectorLabels" -}}
app: harbor
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-harbor.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
