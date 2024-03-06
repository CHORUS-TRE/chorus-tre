# CHORUS
This repository contains all helm charts used across CHORUS environments,
an ArgoCD ApplicationSet to deploy them on K8s clusters through another repository,
as well as Argo Workflows to build docker images used in internal charts.

:warning: Please add/modify only one chart at a time, this is necessary for the Github action to do its job properly :warning:

## **How to add a new helm chart to this repository**

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
 
Finally, after committing this newly created folder, the new chart will be released in this repository and added to the CHORUS OCI registry.

## **How to modify a helm chart in this repository**

Go ahead and modify the files that need to be updated. Bump `version` in `Chart.yaml` and commit.
