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
│           ├── modules
│           │   ├── argo_cd
│           │   └── ...
│           ├── stage_01
│           │   ├── main.tf
│           │   ├── provider.tf
│           │   └── variables.tf
│           ├── stage_02
│           │   ├── main.tf
│           │   ├── provider.tf
│           │   └── variables.tf
│           └── terraform.tfvars
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

1. Stage 1: Initialize, plan and apply

    ```
    cd stage_01
    terraform init
    terraform plan -var-file="../terraform.tfvars" -out="stage_01.plan"
    terraform apply "stage_01.plan"
    cd ..
    ```

> **_NOTE:_** The ```terraform apply``` command can take several minutes to complete

1. Make sure the ```stage_01_output.yaml``` file appeared

1. Update your DNS with the loadbalancer IP address

1. Make sure you can access the Harbor and Keycloak services in the browser, using the URLs described in the ```stage_01_output.yaml``` file

> **_NOTE:_** It takes some time for the certificates to be signed and trusted, hence TLS server verification is currently disabled. If you chose to enable the verification, you might hit the following error: ```tls: failed to verify certificate: x509: certificate signed by unknown authority```

1. Stage 2: Initialize, plan and apply
    ```
    cd stage_02
    terraform init
    terraform plan -var-file="../terraform.tfvars" -out="stage_02.plan"
    terraform apply "stage_02.plan"
    cd ..
    ```

1. Make sure the ```stage_02_output.yaml``` file appeared

1. Find all the URLs, username and password needed in the ```stage_02_output.yaml``` file

## Uninstall

1. Destroy the infrastructure

    ```
    cd stage_02
    terraform destroy -var-file="../terraform.tfvars"
    cd ../stage_01
    terraform destroy -var-file="../terraform.tfvars"
    cd ..
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

> **_NOTE:_** If something goes wrong during the uninstallation, you can run
```./scripts/nuke.sh``` to destroy everything without relying on Terraform