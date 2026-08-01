{{/*
Network policy labels
Uses the upstream chart's selector labels
*/}}
{{- define "networkPolicy.labels" -}}
app.kubernetes.io/name: fluent-operator
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Selector covering every pod this chart is responsible for: the fluent-operator
deployment and the fluent-bit daemonset it reconciles. Rendered as a full
LabelSelector (matchExpressions), usable both as a K8s NP podSelector and as a
CiliumNetworkPolicy endpointSelector.
*/}}
{{- define "networkPolicy.podsSelector" -}}
matchExpressions:
- key: app.kubernetes.io/name
  operator: In
  values:
  - fluent-bit
  - fluent-operator
{{- end }}
