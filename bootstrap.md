# Bootstrap

Basically, what needs to be done when in order to have a fully functioning *Build* environment. Then, we will dive into the *Dev*, *QA*, and *Production* ones.

Everything is in the [bootstrap.sh](./bootstrap.sh) script.

## In a nutshell

This repository contains **all** the charts. They will be deployed by ArgoCD, but some elements are needed before we can get there.

### ArgoCD

ArgoCD will be public facing therefore, it's installing:

 - ingress-nginx, to expose it to the Internet;
 - cert-manager, to provide a LetsEncrypt certificate;
 - and, valkey, as an alternative to the bundled Redis.

Using Valkey as the external Redis is good for two reasons, we control the Redis/Valkey upgrades *and* share the knowledge and love with the other deployments, e.g. for Harbor.

### The Charts

```bash
helm package charts/*
```

And publish them.

```bash
for chart in *.tgz
do
    helm publish $chart oci://harbor.build.chorus-tre.ch/charts/
done
```
