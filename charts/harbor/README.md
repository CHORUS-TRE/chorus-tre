# Harbor

Helm chart wrapping the upstream [habor](https://github.com/goharbor/harbor-helm).

To be tested together with the following secret file, applied before the helm install.

```
apiVersion: v1
kind: Secret
metadata:
  name: harbor-secret-vars
  namespace: harbor
type: Opaque
stringData:
  HARBOR_ADMIN_PASSWORD: "changeme1"
  key: "changeme2withsomethinglongerthan16charslikeyoudusuallydo"
  secretKey: "changeme3"
  #POSTGRESQL_PASSWORD: "secure-postgres-password" #For external DB only TODO
  REGISTRY_PASSWD: "changeme4"
  # Login and password in htpasswd string format. Excludes `registry.credentials.username`  and `registry.credentials.password`. May come in handy when integrating with tools like argocd or flux. This allows the same line to be generated each time the template is rendered, instead of the `htpasswd` function from helm, which generates different lines each time because of the salt.
  # htpasswdString: $apr1$XLefHzeG$Xl4.s00sMSCCcMyJljSZb0 # example string
  # default if empty to keep REGISTRY_PASSWD and registry.credentials.username in use.
  REGISTRY_HTPASSWD: ""
```