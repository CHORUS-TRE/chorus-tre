{{/*
Selector labels matching the upstream chart's dashboard pods. The network
policy covers the dashboard only: the controller, csi-node and mount pods are
not policed by this chart today (none are hostNetwork, so extending coverage
is possible follow-up work).
*/}}
{{- define "chorus-juicefs-csi-driver.dashboardSelectorLabels" -}}
app: juicefs-csi-dashboard
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-juicefs-csi-driver.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
