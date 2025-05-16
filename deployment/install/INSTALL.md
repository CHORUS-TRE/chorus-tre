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
│       └── install
│           ├── INSTALL.md
│           ├── main.tf
│           ├── modules
│           │   ├── argo_cd
│           │   └── ...
│           ├── provider.tf
│           └── variables.tf
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

> **_NOTE:_** We need to install the different CRDs before being able to plan the creation of custom resource objects, therefore the installation requires multiple steps

1. Save the first step of the execution plan:

    ```
    terraform plan \
    -target=module.ingress_nginx \
    -target=module.certificate_authorities \
    -target=module.keycloak \
    -out=chorus_step1.plan
    ```

1. Apply the saved plan:

    ```
    terraform apply chorus_step1.plan
    ```

1. Retrieve the loadbalancer IP address

    ```
    terraform output loadbalancer_ip
    ```

1. Update your DNS server with using the loadbalancer IP address

1. Save the second part of the execution plan:

    ```
    terraform plan \
    -target=module.ingress_nginx \
    -target=module.certificate_authorities \
    -target=module.keycloak \
    -target=module.keycloak_config \
    -target=module.harbor \
    -target=module.harbor_config \
    -target=module.argo_cd \
    -target=module.argo_cd_config \
    -out=chorus_step2.plan
    ```

1. Apply the saved plan:

    ```
    terraform apply chorus_step2.plan
    ```

> **_NOTE:_** If something goes wrong with the output variables, you can run
```terraform apply -refresh-only``` to trigger the output again

1. Display sensitive output (e.g. argocd_password)
    ```
    terraform output argocd_password
    ```

## Uninstall

1. Destroy the infrastructure

    ```
    terraform destroy
    ```

1. Make sure the uninstallation was successful
    ```
    kubectl get ns
    # Expected output: system-level namespace only (e.g. kube-***)
    ```

    ```
    helm list -A
    # Expected output: system-level charts only (e.g. kube-***)
    ```

1. In case resources were not cleaned up correctly
    ```
    helm uninstall problematic-chart -n problematic-namespace
    kubectl delete namespace problematic-namespace
    ```