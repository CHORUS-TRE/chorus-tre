# trivy-operator-crds

A dedicated Helm chart for trivy-operator Custom Resource Definitions (CRDs), designed for independent lifecycle management in GitOps workflows.

## How to Update the Chart

### Prerequisites

- The chart version should match the trivy-operator version you're deploying

### Step 1: Download the trivy-operator CRDs

**Update APP_VERSION to match your target trivy-operator version**

```bash
export APP_VERSION=v0.29.0
export CRD_FILES=($(curl -s "https://api.github.com/repos/aquasecurity/trivy-operator/contents/deploy/helm/crds?ref=$APP_VERSION" | jq -r '.[].name'))

for FILE in $CRD_FILES; do
  curl -s https://raw.githubusercontent.com/aquasecurity/trivy-operator/$APP_VERSION/deploy/helm/crds/$FILE -L -o ./templates/$FILE
done
```
### Step 2: Update Chart Version

Update `Chart.yaml` to match the trivy-operator version:

```yaml
version: 0.29.0  # Match trivy-operator app version
```

### Step 3: Review and Commit

```bash
# Review generated files
ls -la templates/

# Verify CRD content
helm template . | head -100

# Commit changes
git add Chart.yaml templates/
git commit -m "chore: update trivy-operator CRDs to $APP_VERSION"
```
