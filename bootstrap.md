# Bootstrap

What needs to be done when in order to have a fully functioning *Build* environment. The *Dev*, *QA*, and *Production* ones are then managed by Argo CD and the [application sets](./deployment/applicationset/).

Everything described below is in the [bootstrap.sh](./bootstrap.sh) script.

## In a nutshell

This repository contains **all** the charts. They will be deployed by ArgoCD, but some elements are needed before we can get there.

### Prerequisites

A Kubernetes cluster with some kind of `LoadBalancer` enabled. E.g. `k3s` comes with one.

### ArgoCD

ArgoCD will be public facing therefore, it's installing:

 - [ingress-nginx][], to expose it to the Internet;
 - [cert-manager][], to provide a LetsEncrypt certificate;
 - and, [valkey][], as an alternative to the bundled Redis.

Using Valkey as the external Redis is good for two reasons, we control the Redis/Valkey upgrades *and* share the knowledge and love with the other deployments, e.g. for Harbor.

### Harbor

Harbor is also public facing, and requires:

- [ingress-nginx][], same as above;
- [cert-manager][], same as above;
- [valkey][], its own instance;
- [self-signed-issuer][], to generate a certificate for Postgres;
- and, [postgresql][], as the main database.

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

<!-- links -->

[ingress-nginx]: ./charts/ingress-nginx/
[cert-manager]: ./charts/cert-manager/
[valkey]: ./charts/valkey
[self-signed-issuer]: ./charts/self-signed-issuer/
[postgresql]: ./charts/postgresql/
