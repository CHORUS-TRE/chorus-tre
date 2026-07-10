{{/*
Selector labels matching the keycloak server pods created by the Bitnami
subchart (component excludes the config-cli job and the bundled postgresql).
The `chorus-keycloak` prefix avoids collisions with the subchart's own
`keycloak.*` named templates (Helm template names are global).
*/}}
{{- define "chorus-keycloak.selectorLabels" -}}
app.kubernetes.io/name: keycloak
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/component: keycloak
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-keycloak.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: keycloak
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
