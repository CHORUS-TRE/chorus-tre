#!/bin/bash

read -p "Please enter domain name of your CHORUS instance: " DOMAIN_NAME
if [[ -z "$DOMAIN_NAME" ]]; then
  DOMAIN_NAME="chorus-tre.ch"
fi

read -p "Please enter your Let's Encrypt email: " EMAIL
if [[ -z "$EMAIL" ]]; then
  EMAIL="no-reply@chorus-tre.ch"
fi

# install argocd
helm dep update charts/argo-cd
kubectl get namespace | grep -q "^argocd " || kubectl create namespace argocd
helm install chorus-build-argo-cd charts/argo-cd -n argocd --set argo-cd.server.ingress.hosts[0]=argo-cd.build.$DOMAIN_NAME --set argo-cd.server.ingress.tls[0].hosts[0]=argo-cd.build.$DOMAIN_NAME --set argo-cd.server.ingress.tls[0].secretName=argocd-ingress-http --set argo-cd.server.ingressGrpc.hosts[0]=grpc.argo-cd.build.$DOMAIN_NAME --set argo-cd.server.ingressGrpc.tls[0].hosts[0]=grpc.argo-cd.build.$DOMAIN_NAME --set argo-cd.server.ingressGrpc.tls[0].secretName=argocd-ingress-grpc
echo "" 

# install ingress-nginx
helm dep update charts/ingress-nginx
kubectl get namespace | grep -q "^ingress-nginx " || kubectl create namespace ingress-nginx
helm install chorus-build-ingress-nginx charts/ingress-nginx -n ingress-nginx
echo ""

# install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.4/cert-manager.crds.yaml
helm dep update charts/cert-manager
kubectl get namespace | grep -q "^cert-manager " || kubectl create namespace cert-manager
helm install chorus-build-cert-manager charts/cert-manager -n cert-manager --set clusterissuer.email=$EMAIL
echo "" 

# install sealed-secrets
helm dep update charts/sealed-secrets
helm install chorus-build-sealed-secrets charts/sealed-secrets -n kube-system
echo ""

# install registry
kubectl get namespace | grep -q "^registry " || kubectl create namespace registry
helm install chorus-build-registry charts/registry -n registry --set ingress.hosts[0]=registry.build.$DOMAIN_NAME --set ingress.tls[0].hosts[0]=registry.build.$DOMAIN_NAME --set ingress.tls[0].secretName=registry-tls
echo "" 

# wait
echo "Waiting for pods to be ready..."
kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=argocd \
    --timeout=60s
kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=ingress-nginx \
    --timeout=60s
kubectl wait pod \
    --all \
    --for=condition=Ready \
    --namespace=cert-manager \
    --timeout=60s
kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=registry \
    --timeout=60s
echo "" 


# get argocd initial password
echo "ArgoCD username: admin"
echo -n "ArgoCD password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo -e "\n"

# display ArgoCD URL
echo -e "ArgoCD is available at: https://argo-cd.build.$DOMAIN_NAME\n"

# display OCI Registry URL
echo -e "OCI Registry is available at: https://registry.build.$DOMAIN_NAME\n"

# create namespace for launching argo-workflows
kubectl get namespace | grep -q "^argo " || kubectl create namespace argo

# deploy the ApplicationSet
kubectl -n argocd apply -f deployment/applicationset/applicationset-chorus.yaml
