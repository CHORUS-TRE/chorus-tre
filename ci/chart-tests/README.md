# Chart E2E Registry

This directory is the source of truth for chart e2e test configuration.

- `../chart-tests.yaml` is the registry index. It keeps global defaults and small/simple chart entries together.
- `charts/<chart>.yaml` contains larger chart-specific configuration where a separate file improves maintainability.
- The workflow and Python runner merge the index with the per-chart files at runtime into one registry.

Merged structure:

```yaml
defaults:
  namespace: test
  timeout: 120

charts:
  <name>:
    ...
```

Supported chart fields:

- `namespace`: Kubernetes namespace. Defaults to `defaults.namespace`.
- `timeout`: Seconds to wait for pods to become Ready. Defaults to `defaults.timeout`.
- `values`: Inline Helm `--set` overrides.
- `values_file`: Path to a CI-specific values file, relative to the repo root.
- `fullname_override`: Stable Kubernetes object or service name override.
- `skip_deploy`: Skip Helm install for CRD-only or infra-only charts.
- `depends_on`: Other chart names that must be deployed first.
- `dependency_values`: Dynamic `--set` overrides resolved from dependency charts.
- `probe`: Probe pod namespace and labels used for reachability and HTTP checks.
- `pre_install`: Commands run before installing the chart under test.
- `services`: Service ports to probe after deployment.
- `health_check`: Application-level verification.

`dependency_values` supports these attributes:

- `serviceName`
- `releaseName`
- `namespace`
- `servicePort`
- `httpBaseUrl`
- `httpUrl`

`health_check.protocol` supports:

- `http`
- `pg`
- `mariadb`

The workflow also uses the merged registry in reverse: when a dependency chart changes, dependent charts are retested as impacted services and reported as warning-only targets.