#!/bin/bash

# install argocd
helm install chorus-build-argo-cd charts/argo-cd -n argocd
echo "" 

# install caddy-ingress-controller
helm install chorus-build-caddy-ingress-controller charts/caddy-ingress-controller -n caddy-system
echo "" 

# install registry
helm install chorus-build-registry charts/registry -n registry
echo "" 

# wait
kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=argocd \
        --timeout=60s
kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=caddy-system \
        --timeout=60s
kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=registry \
        --timeout=60s
echo "" 

# get argocd initial password
echo -n "ArgoCD password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo -e "\n" 

# create namespace for launching argo-workflows
kubectl create namespace argo

# deploy the ApplicationSet
kubectl -n argocd apply -f deployment/applicationset/applicationset-chorus.yaml
