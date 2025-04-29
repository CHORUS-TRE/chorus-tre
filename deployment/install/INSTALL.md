# How to bootstrap the CHORUS-TRE Build cluster

## Install

1. Set variables for your usecase:

    ```
    cp terraform.tfvars.example terraform.tfvars
    ```

    Edit this file as needed.

1. Fetch the Helm charts version

    ```
    chmod +x scripts/populate-helm-charts-versions.sh && \
    scripts/populate-helm-charts-versions.sh
    ```

1. Initialize terraform:

    ```
    terraform init
    ```

1. Save the execution plan:

    ```
    terraform plan -out=chorus.plan
    ```

1. Apply the saved plan:

    ```
    terraform apply chorus.plan
    ```

## Uninstall

1. Destroy the infrastructure

    ```
    terraform destroy
    ```
