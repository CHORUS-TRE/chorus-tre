{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "chorus-gateway.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "chorus-gateway.labels" -}}
helm.sh/chart: {{ include "chorus-gateway.chart" . }}
app.kubernetes.io/name: {{ .Chart.Name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Single backendRef list for an HTTPRoute, derived from a route entry.
Argument: a route map with serviceName, namespace, servicePort.
*/}}
{{- define "chorus-gateway.backendRef" -}}
- name: {{ required "serviceName is required" .serviceName }}
  namespace: {{ required "namespace is required" .namespace }}
  port: {{ required "servicePort is required" .servicePort }}
{{- end }}

{{/*
Redirect-on-exact-"/" rule used when a route defines redirectPath.
Gateway API evaluates matches-bearing rules before match-less ones, so this
takes precedence over the catchall backendRefs that follows in the template.
Argument: a route map with redirectPath.
*/}}
{{- define "chorus-gateway.redirectOnRoot" -}}
- matches:
    - path:
        type: Exact
        value: /
  filters:
    - type: RequestRedirect
      requestRedirect:
        path:
          type: ReplaceFullPath
          replaceFullPath: {{ .redirectPath | quote }}
{{- end }}

{{/*
SecurityPolicy authorization rule scoped to the cluster pod CIDR.
Argument: dict with keys `name` (rule name), `action` ("Allow" or "Deny"),
`podCIDR` (the cluster pod CIDR as a string).
*/}}
{{- define "chorus-gateway.podCIDRRule" -}}
- name: {{ .name }}
  action: {{ .action }}
  principal:
    clientCIDRs:
      - {{ required "podCIDR must be set to match the cluster's pod CIDR" .podCIDR | quote }}
{{- end }}

{{/*
Route-name helpers — centralize the naming convention so renaming a suffix
is a one-line change in _helpers.tpl rather than chasing strings across
multiple templates. All take a route map and return "<route.name>-<suffix>".
*/}}
{{- define "chorus-gateway.internalHTTPRouteName" -}}
{{- printf "%s-internal-httproute" (required "name is required" .name) -}}
{{- end }}

{{- define "chorus-gateway.externalHTTPRouteName" -}}
{{- printf "%s-external-httproute" (required "name is required" .name) -}}
{{- end }}

{{- define "chorus-gateway.oauth2HTTPRouteName" -}}
{{- printf "%s-oauth2-httproute" (required "name is required" .name) -}}
{{- end }}

{{- define "chorus-gateway.openHTTPRouteName" -}}
{{- printf "%s-open-httproute" (required "name is required" .name) -}}
{{- end }}

{{- define "chorus-gateway.internalTCPRouteName" -}}
{{- printf "%s-internal-tcproute" (required "name is required" .name) -}}
{{- end }}

{{- define "chorus-gateway.extAuthSecurityPolicyName" -}}
{{- printf "%s-extauth-securitypolicy" (required "name is required" .name) -}}
{{- end }}

{{- define "chorus-gateway.externalOIDCSecurityPolicyName" -}}
{{- printf "%s-external-oidc-securitypolicy" (required "name is required" .name) -}}
{{- end }}

{{- define "chorus-gateway.openOIDCSecurityPolicyName" -}}
{{- printf "%s-open-oidc-securitypolicy" (required "name is required" .name) -}}
{{- end }}
