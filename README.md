# CHORUS-TRE

This repository contains all helm charts used across CHORUS environments,
an ArgoCD ApplicationSet to deploy them on K8s clusters through the `environments-template` repository,
as well as Argo Workflows to build docker images used in internal charts.

## Contribute to this repository

### Add a new helm chart

:warning: Please add/modify only one chart at a time, this is necessary for the Github action to do its job properly :warning:

#### External chart
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

`values.yaml`:
```yaml
<helm_chart_name>:
  #add the values that must be customized for all CHORUS environments
```

From the `charts` folder, run
```bash
helm dep update <helm_chart_name>
```
to add the `Chart.lock` file to be committed.

#### Internal chart

If the chart is internal, create a new chart in the `charts` folder using:

```bash
helm create <helm_chart_name>
```
or add your own chart. Chart numbering starts at `0.0.1` for all charts.

Finally, after committing this newly created folder, the new chart will be automatically released in this repository and pushed to the CHORUS helm OCI registry.

### Update/modify a helm chart

Go ahead and modify the files that need to be updated. Bump `version` in `Chart.yaml` and commit. A new release of the chart will be released to this repository and pushed to the CHORUS helm OCI registry.

## License and Usage Restrictions

Any use of the software for purposes other than academic research, including for commercial purposes, shall be requested in advance from [CHUV](mailto:pactt.legal@chuv.ch).

## Acknowledgments

This project has received funding from the Swiss State Secretariat for Education, Research and Innovation (SERI) under contract number 23.00638, as part of the Horizon Europe project “EBRAINS 2.0”.
