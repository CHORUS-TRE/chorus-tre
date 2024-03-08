# CHORUS
This repository contains all helm charts used across CHORUS environments,
an ArgoCD ApplicationSet to deploy them on K8s clusters through another repository,
as well as Argo Workflows to build docker images used in internal charts.

## How to install CHORUS

CHORUS runs on Kubernetes. Make sure your `KUBECONFIG` environment variable points to a Kubernetes cluster, where the `build` environment of CHORUS will be installed.

1. Clone this repository:
   ```bash
   git clone git@github.com:CHORUS-TRE/chorus.git
   ```
2. Fork https://github.com/CHORUS-TRE/environments-template to your GitHub organization.
3. Modify the ApplicationSet template for your use case:
   ```bash
   cd chorus
   mv deployment/applicationset-chorus.template.yaml deployment/applicationset-chorus.yaml
   ```
   In this file, change the links to `https://github.com/<YOUR-ORG>/environments-template` to your new fork.
   
4. Execute the bootstrapping script:
   ```bash
   ./bootstrap.sh
   ```
This will bootstrap the installation of ArgoCD as well as the OCI registry.



:warning: Please add/modify only one chart at a time, this is necessary for the Github action to do its job properly :warning:

## How to add a new helm chart to this repository

### External chart
If the chart is external, add a new folder in `charts`. Its name should be the same as the chart's name to be added.
Add the following two files to the folder:

`Chart.yaml`:
```yaml
apiVersion: v2
description: <helm_chart_description>
name: <helm_chart_name>
version: 0.0.1
dependencies:
  - name: <helm_chart_name>
    version: <helm_chart_version>
    repository: <helm_chart_repository>
```

`values.yaml`: add the values that must be customized for all CHORUS environments.

From the `charts` folder, run
```bash
helm dep update <helm_chart_name>
```
to add the `Chart.lock` file to be committed.

### Internal chart

If the chart is internal, create a new chart in the `charts` folder using:

```bash
helm create <helm_chart_name>
```
or add your own chart. Chart numbering starts at `0.0.1` for all charts.
 
Finally, after committing this newly created folder, the new chart will be automatically released in this repository and pushed to the CHORUS helm OCI registry.

## **How to modify a helm chart in this repository**

Go ahead and modify the files that need to be updated. Bump `version` in `Chart.yaml` and commit. A new release of the chart will be released to this repository and pushed to the CHORUS helm OCI registry.
