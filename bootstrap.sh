#!/bin/bash

# install argocd
helm dep update charts/argo-cd
kubectl get namespace | grep -q "^argocd " || kubectl create namespace argocd
helm install chorus-build-argo-cd charts/argo-cd -n argocd
echo "" 

# install caddy-ingress-controller
helm dep update charts/caddy-ingress-controller
kubectl get namespace | grep -q "^caddy-system " || kubectl create namespace caddy-system
helm install chorus-build-caddy-ingress-controller charts/caddy-ingress-controller -n caddy-system
echo "" 

# install registry
kubectl get namespace | grep -q "^registry " || kubectl create namespace registry
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
kubectl get namespace | grep -q "^argo " || kubectl create namespace argo

# deploy the ApplicationSet
kubectl -n argocd apply -f deployment/applicationset/applicationset-chorus.yaml
