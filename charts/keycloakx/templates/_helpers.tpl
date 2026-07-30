{{/*
Selector labels matching the keycloakx server pods created by the codecentric
subchart (aliased `keycloak`, so pods carry app.kubernetes.io/name: keycloak).
Scoped to this release so the policy doesn't collide with another keycloak
chart briefly coexisting in the same namespace. The `chorus-keycloakx` prefix
avoids collisions with the subchart's own named templates.
*/}}
{{- define "chorus-keycloakx.selectorLabels" -}}
app.kubernetes.io/name: keycloak
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-keycloakx.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
