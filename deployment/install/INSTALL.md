# How to bootstrap the CHORUS-TRE Build cluster

## Project structure

```
.
├── chorus-tre
│   ├── charts
│   │   ├── argo-cd
│   │   │   ├── Chart.lock
│   │   │   ├── Chart.yaml
│   │   │   └── values.yaml
│   │   └── ...
│   └── deployment
│   │   └── install
│   │       ├── INSTALL.md
│   │       ├── main.tf
│   │       ├── modules
│   │       │   ├── argo_cd
│   │       │   └── ...
│   │       ├── provider.tf
│   │       └── variables.tf
└── environment-template
    └── chorus-build
        ├── argo-cd
        │   ├── config.json
        │   └── values.yaml
        └── ...

```

Required repositories

- [chorus-tre](https://github.com/CHORUS-TRE/chorus-tre)
- [environment-template](https://github.com/CHORUS-TRE/environment-template)

## Install

1. Set variables for your usecase:

    ```
    cp terraform.tfvars.example terraform.tfvars
    ```

    Edit this file as needed.

1. Pull the necessary Helm charts and copy over their versions

    ```
    chmod +x scripts/init_helm_charts.sh && \
    scripts/init_helm_charts.sh
    ```

1. Initialize terraform:

    ```
    terraform init
    ```

1. Save the first step of the execution plan:

    ```
    terraform plan \
    -target=module.ingress_nginx \
    -target=module.certificate_authorities \
    -target=module.argo_cd \
    -target=module.keycloak \
    -out=chorus_step1.plan
    ```

1. Apply the saved plan:

    ```
    terraform apply chorus_step1.plan
    ```

> **_NOTE:_** We need to install the different CRDs before being able to plan the creation of custom resource objects, hence the two steps installation

!!! warning
hello

1. Save the whole execution plan:

    ```
    terraform plan -out=chorus_step2.plan
    ```

1. Apply the saved plan:

    ```
    terraform apply chorus_step2.plan
    ```

## Uninstall

1. Destroy the infrastructure

    ```
    terraform destroy
    ```
