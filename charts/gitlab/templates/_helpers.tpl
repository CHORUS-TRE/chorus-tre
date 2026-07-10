{{- define "gitlab.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{- define "gitlab.labels" -}}
helm.sh/chart: {{ include "gitlab.chart" . }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels matching every pod of the upstream gitlab chart (webservice,
sidekiq, gitaly, gitlab-shell, toolbox, exporter — they all carry the classic
`release` label). Deliberately NOT namespace-wide: the gitlab namespace also
hosts the gitlab-db (postgresql) and gitlab-cache (valkey) releases, whose own
stricter policies must not be widened by union with this one.
*/}}
{{- define "chorus-gitlab.selectorLabels" -}}
release: {{ .Release.Name }}
{{- end }}

{{/*
Common labels for the chorus network-policy objects (the `chorus-gitlab`
prefix avoids colliding with the upstream chart's `gitlab.*` templates).
*/}}
{{- define "chorus-gitlab.labels" -}}
helm.sh/chart: {{ include "gitlab.chart" . }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
