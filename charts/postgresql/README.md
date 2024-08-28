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

And a second one, for the certificate which can be created via the `certificate.enabled` value.

## Resources

Tweak the `resourcesPreset` [accordingly](https://github.com/bitnami/charts/blob/main/bitnami/common/templates/_resources.tpl#L15) or use the proper `resources` in production setup.

<!-- links -->
[postgresql]: https://github.com/bitnami/charts/tree/main/bitnami/postgresql
