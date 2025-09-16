# Technical Context: CHORUS-TRE

This document outlines the core technologies and platforms that constitute the CHORUS-TRE ecosystem.

## 1. Core Technologies

*   **Kubernetes**: The container orchestration platform that runs all CHORUS applications and services. This is the target environment for all deployments.
*   **Helm**: The package manager for Kubernetes. All applications are packaged as Helm charts, which provides a templating and versioning mechanism for Kubernetes manifests.
*   **ArgoCD**: The declarative, GitOps continuous delivery tool for Kubernetes. ArgoCD is responsible for ensuring that the live state of the applications in the Kubernetes clusters matches the desired state defined in this Git repository.
*   **Argo Workflows**: The container-native workflow engine for orchestrating parallel jobs on Kubernetes. It is used here to define and execute the build pipelines for creating Docker images.
*   **Docker**: The container runtime used for packaging applications and their dependencies into portable images.

## 2. CI/CD and Automation

*   **GitHub Actions**: The primary CI/CD platform. It is used to automate the process of testing, versioning, and releasing Helm charts. When a chart's version is updated, a GitHub Action automatically creates a new release and pushes the chart to the OCI registry.
*   **Helm OCI Registry**: The project uses an OCI (Open Container Initiative) compliant registry to store and distribute its Helm charts. This provides a standardized and secure way to manage chart artifacts.

## 3. Key Services (from charts)

Based on the charts present in the repository, the CHORUS ecosystem utilizes several key open-source services, including but not limited to:

*   **Ingress-Nginx**: For managing external access to the services in the cluster.
*   **Cert-Manager**: For automating the management and issuance of TLS certificates.
*   **Keycloak**: For identity and access management.
*   **PostgreSQL / MariaDB**: As relational database backends.
*   **Valkey / Redis**: For in-memory data storage (e.g., caching, session management).
*   **Prometheus Stack / Trivy**: For monitoring, alerting, and security scanning.
*   **Harbor**: As a container registry for Docker images.
