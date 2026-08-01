{{/*
Selector labels matching every pod of the upstream argo-cd chart (server,
repo-server, application-controller, applicationset-controller, bundled
redis — they all carry the static part-of label; one argo-cd install per
namespace by construction). The `chorus-argo-cd` prefix avoids collisions
with the subchart's own named templates.
*/}}
{{- define "chorus-argo-cd.selectorLabels" -}}
app.kubernetes.io/part-of: argocd
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-argo-cd.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
