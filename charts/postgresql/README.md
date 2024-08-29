# Postgresql chart

Helm chart wrapping the upstream [postgresql][].

## Secrets

A secret is needed for the user.

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-secret
type: Opaque
stringData:
  postgres-password: postgres
  password: $(pwgen 16 1)
```

And a second one, for the certificate.

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: postgresql-general-tls
spec:
  secretName: postgresql-general-tls

  privateKey:
    algorithm: ECDSA
    size: 256

  duration: 2160h # 90d
  renewBefore: 360h # 15d

  isCA: false
  usages:
    - server auth
    - client auth
  subject:
    organizations:
      - chorus
  uris:
    - spiffe://cluster.local/ns/MYNAMESPACE

  privateKey:
    rotationPolicy: Always

  issuerRef:
    name: CHANGEME
    kind: ClusterIssuer # or Issuer
    group: cert-manager.io
```

## Resources

Tweak the `resourcesPreset` [accordingly](https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15) or use the proper `resources` in production setup.

<!-- links -->
[postgresql]: https://github.com/bitnami/charts/tree/main/bitnami/postgresql
