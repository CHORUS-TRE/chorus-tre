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

Deployable charts should define at least one downstream `services` or `health_check` check. If Helm `install --wait` fails and the runner has to retry without `--wait`, the run now fails when neither check type is configured because readiness would otherwise be unverified.

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

CLI entrypoints:

- `../run-chart-e2e-workflow.py` is the live repo-level entrypoint used by the Argo sensor. It renders the merged registry, plans targets, creates the Kind cluster, and runs the full repo workflow.
- `../plan-chart-e2e.py` is an intentional local/manual planner helper. It prints planned targets to stdout and can optionally write `--targets-file`, `--github-output`, and `--step-summary` files when a wrapper wants them.
- `../run-chart-e2e.py` is an intentional local/manual single-chart runner for debugging one chart without going through the repo-level workflow.

Known caveat:

- CRD charts are not auto-detected from a `*-crds` chart name. If a new CRD-only chart is added, it still needs an explicit `skip_deploy: true` entry in [ci/chart-tests.yaml](ci/chart-tests.yaml) until that convention is implemented in code.
