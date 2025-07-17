# Project Brief: CHORUS-TRE

## 1. Project Overview

CHORUS-TRE (Trusted Research Environment) is a centralized repository for managing and deploying infrastructure components for the CHORUS project. It contains all Helm charts, deployment configurations (via ArgoCD), and CI/CD workflows (via Argo Workflows) required to build and maintain CHORUS environments on Kubernetes.

## 2. Core Components

*   **Helm Charts**: The repository houses a collection of both internal and third-party Helm charts used across all CHORUS environments. This ensures consistent and version-controlled deployments.
*   **ArgoCD ApplicationSet**: It includes an ArgoCD ApplicationSet that leverages the `environments-template` repository to automate the deployment of these charts onto Kubernetes clusters.
*   **Argo Workflows**: The project utilizes Argo Workflows to automate the building of Docker images for internal applications and services.

## 3. Key Goals and Requirements

*   **Centralized Management**: To provide a single source of truth for all Kubernetes-based application and service configurations for the CHORUS project.
*   **Automated Deployments**: To automate the deployment process, ensuring consistency and reducing manual intervention.
*   **Automated Builds**: To automate the container image build process for internal components.
*   **Version Control**: To version all infrastructure-as-code components, enabling rollbacks and auditable changes.
*   **Extensibility**: To provide clear guidelines for contributors to add new applications (charts) or modify existing ones.

## 4. Contribution Guidelines

*   Modifications should be made to one chart at a time to ensure the CI/CD pipeline functions correctly.
*   Clear instructions are provided for adding both new external and internal Helm charts.
*   Chart versioning must be bumped in `Chart.yaml` upon modification to trigger a new release.

## 5. License and Usage

*   The software is intended for **academic research purposes only**.
*   Any commercial use requires prior written permission from the CHUV (Centre hospitalier universitaire vaudois). Contact: [pactt.legal@chuv.ch](mailto:pactt.legal@chuv.ch).

## 6. Funding

This project is funded by the Swiss State Secretariat for Education, Research and Innovation (SERI) under contract number 23.00638, as part of the Horizon Europe project “EBRAINS 2.0”.
