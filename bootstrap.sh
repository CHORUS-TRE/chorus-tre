#!/bin/bash

# install argocd
microk8s helm3 install horus-build-argo-cd charts/argo-cd -n argocd
echo "" 

# install caddy-ingress-controller
microk8s helm install horus-build-caddy-ingress-controller charts/caddy-ingress-controller -n caddy-system
echo "" 

# install registry
microk8s helm install horus-build-registry charts/registry -n registry
echo "" 

# wait
microk8s kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=argocd \
        --timeout=60s
microk8s kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=caddy-system \
        --timeout=60s
microk8s kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=registry \
        --timeout=60s
echo "" 

# get argocd initial password
echo -n "ArgoCD password: "
microk8s kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo -e "\n" 

# create namespace for launching argo-workflows
microk8s kubectl create namespace argo

# deploy the applicatinset
microk8s kubectl -n argocd apply -f deployment/applicationset/applicationset-horus.yaml
