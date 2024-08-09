#!/bin/bash

# Exit on error
set -e

read -p "Please enter domain name of your CHORUS instance: " DOMAIN_NAME
if [[ -z "$DOMAIN_NAME" ]]; then
	DOMAIN_NAME="chorus-tre.ch"
fi

read -p "Please enter your Let's Encrypt email: " EMAIL
if [[ -z "$EMAIL" ]]; then
	EMAIL="no-reply@chorus-tre.ch"
fi

# install ingress-nginx
helm dep update charts/ingress-nginx
helm install chorus-build-ingress-nginx charts/ingress-nginx -n ingress-nginx --create-namespace
echo ""
echo "Waiting for ingress-nginx..."
kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=ingress-nginx \
	--timeout=60s

# install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.15.2/cert-manager.crds.yaml
helm dep update charts/cert-manager
helm install chorus-build-cert-manager charts/cert-manager -n cert-manager --create-namespace --set clusterissuer.email=$EMAIL
echo ""
echo "Waiting for cert-manager..."
kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=cert-manager \
	--timeout=60s

# install argocd
helm dep update charts/argo-cd
helm install chorus-build-argo-cd charts/argo-cd -n argocd --create-namespace --set argo-cd.global.domain=argo-cd.build.$DOMAIN_NAME --set argo-cd.server.ingress.extraTls[0].hosts[0]=argo-cd.build.$DOMAIN_NAME --set argo-cd.server.ingress.extraTls[0].secretName=argocd-ingress-http --set argo-cd.server.ingressGrpc.extraTls[0].hosts[0]=grpc.argo-cd.build.$DOMAIN_NAME --set argo-cd.server.ingressGrpc.extraTls[0].secretName=argocd-ingress-grpc
echo ""
echo "Waiting for argo-cd..."
kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=argocd \
	--selector app.kubernetes.io/name!=argocd-redis-secret-init \
	--timeout=60s

# install registry
helm install chorus-build-registry charts/registry -n registry --create-namespace --set ingress.hosts[0]=registry.build.$DOMAIN_NAME --set ingress.tls[0].hosts[0]=registry.build.$DOMAIN_NAME --set ingress.tls[0].secretName=registry-tls
echo ""
echo "Waiting for registry..."
kubectl wait pod \
	--all \
	--for=condition=Ready \
	--namespace=registry \
	--timeout=60s

# install sealed-secrets
helm dep update charts/sealed-secrets
helm install chorus-build-sealed-secrets charts/sealed-secrets -n kube-system
echo ""
echo "Waiting for sealed-secrets..."
kubectl wait pod \
	--for=condition=Ready \
	--namespace=kube-system \
	--selector 'app.kubernetes.io/name=sealed-secrets' \
	--timeout=60s

# get argocd initial password
echo "ArgoCD username: admin"
echo -n "ArgoCD password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo -e "\n"

# display ArgoCD URL
echo -e "ArgoCD is available at: https://argo-cd.build.$DOMAIN_NAME\n"

# display OCI Registry URL
echo -e "OCI Registry is available at: https://registry.build.$DOMAIN_NAME\n"

# deploy the ApplicationSet
kubectl -n argocd apply -f deployment/applicationset/applicationset-chorus.yaml

# display DNS records
ARGOCD_EXTERNAL_IP=$(kubectl -n argocd get ingress chorus-build-argo-cd-argocd-server -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
GRPC_ARGOCD_EXTERNAL_IP=$(kubectl -n argocd get ingress chorus-build-argo-cd-argocd-server-grpc -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
REGISTRY_EXTERNAL_IP=$(kubectl -n registry get ingress chorus-build-registry -o jsonpath="{.status.loadBalancer.ingress[0].ip}")

echo ""
echo -e "Please set the following DNS records:\n"
echo -e "argo-cd.build.$DOMAIN_NAME -> $ARGOCD_EXTERNAL_IP"
echo -e "grpc.argo-cd.build.$DOMAIN_NAME -> $GRPC_ARGOCD_EXTERNAL_IP"
echo -e "registry.build.$DOMAIN_NAME -> $REGISTRY_EXTERNAL_IP"

# argo-workflows setup
# create namespace for launching argo-workflows
#kubectl get namespace | grep -q "^argo " || kubectl create namespace argo
# TODO: test this section
#kubectl wait pod \
#    --for=condition=Ready \
#    --namespace=kube-system \
#    --selector 'app.kubernetes.io/part-of=argo-workflows' \
#    --timeout=60s

#move this to argo-ci chart
#kubectl -n argo apply -f ci/sa_role.yaml
#kubectl -n argo create sa argo-ci
#kubectl -n argo create rolebinding argo-ci --role=argo-ci --serviceaccount=argo:argo-ci
#kubectl -n argo apply -f ci/sa_secret.yaml

#echo -e "Set the following environment variables to submit argo-workflows:\n"
#echo "export ARGO_NAMESPACE=argo"
#echo "ARGO_TOKEN=\"Bearer $(kubectl -n argo get secret argo-ci-sa.service-account-token -o=jsonpath='{.data.token}' | base64 --decode)\""

#argo auth token
#argo list
#argo template list
#argo submit --from WorkflowTemplate/ci-test -n argo --watch
#argo logs -n argo @latest

# argo-events setup
# TODO: test this section
#kubectl wait pod \
#    --for=condition=Ready \
#    --namespace=argo-events \
#    --selector 'app.kubernetes.io/part-of=argo-events' \
#    --timeout=60s
# kubectl apply -n argo-events -f https://raw.githubusercontent.com/argoproj/argo-events/stable/examples/sensors/github.yaml
