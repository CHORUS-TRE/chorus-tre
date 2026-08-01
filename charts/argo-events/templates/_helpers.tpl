{{/*
Selector labels matching the upstream chart's controller-manager pods (the
only workload this chart deploys; the eventbus/eventsource/sensor pods it
manages run in application namespaces under those charts' policies). The
`chorus-argo-events` prefix avoids collisions with the subchart's own named
templates.
*/}}
{{- define "chorus-argo-events.selectorLabels" -}}
app.kubernetes.io/part-of: argo-events
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-argo-events.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
