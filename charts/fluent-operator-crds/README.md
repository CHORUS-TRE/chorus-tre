# fluent-operator-crds

A dedicated Helm chart for fluent-operator Custom Resource Definitions (CRDs), designed for independent lifecycle management in GitOps workflows.

## How to Update the Chart

### Prerequisites

- The chart version should match the fluent-operator version you're deploying
- Install [kubectl-slice](https://github.com/patrickdappollonio/kubectl-slice)

### Step 1: Download the fluent-operator setup file

**Update APP_VERSION to match your target fluent-operator version**

```bash
export APP_VERSION=v3.5.0
curl https://github.com/fluent/fluent-operator/releases/download/$APP_VERSION/setup.yaml -L -o fluent-operator-setup.yaml
```

### Step 2: Split the setup file into Individual Files

Use `kubectl-slice` to split the single YAML into individual files:

```bash
kubectl-slice --input-file=fluent-operator-setup.yaml --output-dir=templates
```

### Step 3: Remove non-CRD files

```bash
find templates -maxdepth 1 -type f ! -name 'customresourcedefinition*' -delete
```

### Step 4: Update Chart Version

Update `Chart.yaml` to match the fluent-operator version:

```yaml
version: 3.5.0  # Match fluent-operator version
```

### Step : Review and Commit

```bash
# Review generated files
ls -la templates/

# Verify CRD content
helm template . | head -100

# Commit changes
git add Chart.yaml templates/
git commit -m "chore: update fluent-operator CRDs to $APP_VERSION"
```
