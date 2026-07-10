{{/*
Selector labels matching ONLY the Envoy Gateway controller pods
(control-plane label). The data-plane Envoy proxy pods it provisions in the
same namespace carry `app.kubernetes.io/managed-by: envoy-gateway` instead and
are governed by the chorus-gateway chart's CiliumNetworkPolicies — they must
never fall under this policy's default-deny. The `chorus-gateway-helm` prefix
avoids collisions with the subchart's own named templates.
*/}}
{{- define "chorus-gateway-helm.selectorLabels" -}}
control-plane: envoy-gateway
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-gateway-helm.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
