# cert-manager-crds

A dedicated Helm chart for cert-manager Custom Resource Definitions (CRDs), designed for independent lifecycle management in GitOps workflows.

## How to Update the Chart

### Prerequisites

- The chart version should match the cert-manager version you're deploying
- Install [kubectl-slice](https://github.com/patrickdappollonio/kubectl-slice)

### Step 1: Download the CRDs

**Update APP_VERSION to match your target cert-manager version**

```bash
export APP_VERSION=v1.18.2
cd charts/cert-manager-crds
curl https://github.com/cert-manager/cert-manager/releases/download/$APP_VERSION/cert-manager.crds.yaml -L -o cert-manager.crds.yaml
```

### Step 2: Split CRDs into Individual Files

Use `kubectl-slice` to split the single YAML into individual CRD files:

```bash
kubectl-slice --input-file=cert-manager.crds.yaml --output-dir=templates
```

This will create one file per CRD in the `templates/` directory with names like:
- `customresourcedefinition-certificaterequests.cert-manager.io.yaml`
- `customresourcedefinition-certificates.cert-manager.io.yaml`
- `customresourcedefinition-challenges.acme.cert-manager.io.yaml`
- etc.

### Step 3: Update Chart Version

Update `Chart.yaml` to match the cert-manager version:

```yaml
version: 1.18.2  # Match cert-manager version
```

### Step 4: Review and Commit

```bash
# Review generated files
ls -la templates/

# Verify CRD content
helm template . | head -100

# Commit changes
git add Chart.yaml templates/
git commit -m "chore: update cert-manager CRDs to $APP_VERSION"
```
