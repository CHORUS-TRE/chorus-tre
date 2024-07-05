# Harbor

Helm chart wrapping the upstream [habor](https://github.com/goharbor/harbor-helm).
It expects a secret in the format below to exist.

```
apiVersion: v1
kind: Secret
metadata:
  name: harbor-secret-vars
  namespace: harbor
type: Opaque
stringData:
apiVersion: v1
kind: Secret
metadata:
  name: harbor-secret-vars
  namespace: harbor
type: Opaque
stringData:
  HARBOR_ADMIN_PASSWORD: "ch@ngeme1"
  key: "ch@ngeme2"
  secret: "ch@ngeme3"
  secretKey: "ch@ngeme4"
  REGISTRY_PASSWD: "ch@ngeme5"
  JOBSERVICE_SECRET: "ch@ngeme6"
  # Login and password in htpasswd string format. Excludes `registry.credentials.username`  and `registry.credentials.password`. May come in handy when integrating with tools like argocd or flux. This allows the same line to be generated each time the template is rendered, instead of the `htpasswd` function from helm, which generates different lines each time because of the salt.
  # htpasswdString: $apr1$XLefHzeG$Xl4.s00sMSCCcMyJljSZb0 # example string
  # default if empty, keep REGISTRY_PASSWD and registry.credentials.username in use.
  REGISTRY_HTPASSWD: ""
```