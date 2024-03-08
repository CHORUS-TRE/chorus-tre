# CHORUS
[CHORUS-TRE](https://www.chorus-tre.ch) is a secure Trusted Research Environment developed by the University Hospital of Lausanne [BDSC team](https://www.chuv.ch/en/bdsc/).

This repository contains all helm charts used across CHORUS environments,
an ArgoCD ApplicationSet to deploy them on K8s clusters through the `environments-template` repository,
as well as Argo Workflows to build docker images used in internal charts.

## Prerequisites

### Local machine tools
| Component                                                          | Description                                                                                                                                                                                                      |
| ------------------------------------------------------------------ | ---------------------------------------------------- |
| [Git](https://git-scm.com/downloads)                               | Git is required to clone this repository             |
| [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) | Kubernetes command-line tool, kubectl, allows you to run commands against Kubernetes clusters                                                                                                                    |
| [helm 3](https://github.com/helm/helm#install)                     | Helm Charts are used to package Kubernetes resources for each component 

### Infrastructure
| Component          | Description                                                                                                        | Required |
| ------------------ | ------------------------------------------------------------------------------------------------------------------ | -------- |
| Kubernetes cluster | An infrastructure with working installation of Kubernetes services. | Required |
| Domain name        | CHORUS-TRE is only accessible via HTTPS and it's essential register a domain name via registrars like Cloudflare, Route53, etc. | Required |  
| DNS Server         | CHORUS-TRE is only accessible via HTTPS and it's essential to have a DNS server via providers like Cloudflare, Route53, etc.                  | Required |
## Installation

1. Make sure your `KUBECONFIG` environment variable points to a Kubernetes cluster, where the `build` environment of CHORUS will be installed.
2. Clone this repository:
   ```bash
   git clone git@github.com:CHORUS-TRE/chorus.git
   ```
3. Fork https://github.com/CHORUS-TRE/environments-template to your GitHub organization.
4. Modify the ApplicationSet template for your use case:
   ```bash
   cd chorus
   mv deployment/applicationset-chorus.template.yaml deployment/applicationset-chorus.yaml
   ```
   In this file, change the links to `https://github.com/<YOUR-ORG>/environments-template` to your new fork.
   
5. Execute the bootstrapping script:
   ```bash
   ./bootstrap.sh
   ```
This will bootstrap the installation of ArgoCD as well as the OCI registry.

## Contributing to this repository

### Adding a new helm chart

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

`values.yaml`: add the values that must be customized for all CHORUS environments.

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

### Updating/modifying a helm chart

Go ahead and modify the files that need to be updated. Bump `version` in `Chart.yaml` and commit. A new release of the chart will be released to this repository and pushed to the CHORUS helm OCI registry.
