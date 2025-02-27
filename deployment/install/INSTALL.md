# How to bootstrap the CHORUS-TRE Build cluster

## Install

1. Set variables for your usecase:

```
cp terraform.tfvars.example terraform.tfvars
```

Edit this file as needed.

2. Initialize terraform:

```
terraform init
```

3. Save the execution plan:

```
terraform plan -out=chorus.plan
```

4. Apply the saved plan:

```
terraform apply chorus.plan
```

## Uninstall

1. Destroy the infrastructure

```
terraform destroy
```
