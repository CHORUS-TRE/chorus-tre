#!/bin/bash

# Exit on error
set -e
set -o pipefail

read -p "Please enter domain name of your CHORUS instance: " DOMAIN_NAME
if [ -z "$DOMAIN_NAME" ]; then
    DOMAIN_NAME="chorus-tre.ch"
fi

read -p "Please enter your Let's Encrypt email: " EMAIL
if [ -z "$EMAIL" ]; then
    EMAIL="no-reply@chorus-tre.ch"
fi

CLUSTER_NAME=chorus-build

# Namespaces
NS_INGRESS=ingress-nginx
NS_CERTMANAGER=cert-manager
NS_ARGOCD=argocd

# Secrets
SECRET_ARGOCD_CACHE=argo-cd-cache-secret

# Install Ingress-NGINX
helm dep update charts/ingress-nginx
helm upgrade --install ${CLUSTER_NAME}-ingress-nginx charts/ingress-nginx \
    -n "${NS_INGRESS}" \
    --create-namespace \
    --wait\

# install Cert-Manager
helm dep update charts/cert-manager
helm upgrade --install ${CLUSTER_NAME}-cert-manager charts/cert-manager \
    -n "${NS_CERTMANAGER}" \
    --create-namespace \
    --set "clusterissuer.email=$EMAIL" \
    --wait

# install Valkey/Redis for ArgoCD
if [ -e "$(kubectl get secret "${SECRET_ARGOCD_CACHE}" --ignore-not-found)" ]
then
    if [ -e "$(kubectl get ns "${NS_ARGOCD}" --ignore-not-found)" ]
    then
        kubectl create ns "${NS_ARGOCD}"
    fi

    redis_password="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
    kubectl create secret generic \
        "${SECRET_ARGOCD_CACHE}" \
        -n "${NS_ARGOCD}" \
        --from-literal "redis-username=admin" \
        --from-literal "redis-password=${redis_password}"
fi

helm dep udpate charts/valkey
helm upgrade --install ${CLUSTER_NAME}-argo-cd-cache charts/valkey \
    -n "${NS_ARGOCD}" \
    --create-namespace \
    --set valkey.auth.enabled=true \
    --set valkey.auth.sentinel=false \
    --set "valkey.auth.existingSecret=${SECRET_ARGOCD_CACHE}" \
    --set valkey.auth.existingSecretPasswordKey=redis-password \
    --wait

# install Argo CD
# it's using the above Valkey server (aka Redis).
# FIXME: in environments, we've got many annotations here.
helm dep update charts/argo-cd
helm upgrade --install ${CLUSTER_NAME}-argo-cd charts/argo-cd \
    -n "${NS_ARGOCD}" \
    --set argo-cd.enabled=false \
    --set argo-cd.redisSecretInit.enabled=false \
    --set argo-cd.externalRedis.host=${CLUSTER_NAME}-argo-cd-cache-valkey-primary \
    --set argo-cd.externalRedis.existingSecret=${SECRET_ARGOCD_CACHE} \
    --set argo-cd.global.domain=argo-cd.build.$DOMAIN_NAME \
    --set argo-cd.server.ingress.extraTls[0].hosts[0]=argo-cd.build.$DOMAIN_NAME \
    --set argo-cd.server.ingress.extraTls[0].secretName=argocd-ingress-http \
    --set argo-cd.server.ingressGrpc.extraTls[0].hosts[0]=grpc.argo-cd.build.$DOMAIN_NAME \
    --set argo-cd.server.ingressGrpc.extraTls[0].secretName=argocd-ingress-grpc \
    --wait

# TODO:  move to harbor
# which needs postgres *and* valkey (same as above);
# and a bunch of secrets of its own, obviously.

# install registry
helm upgrade --install chorus-build-registry charts/registry -n registry --create-namespace --set ingress.hosts[0]=registry.build.$DOMAIN_NAME --set ingress.tls[0].hosts[0]=registry.build.$DOMAIN_NAME --set ingress.tls[0].secretName=registry-tls
echo ""
echo "Waiting for registry..."
kubectl wait pod \
    --all \
    --for=condition=Ready \
    --namespace=registry \
    --timeout=60s

# install sealed-secrets
helm dep update charts/sealed-secrets
helm upgrade --install chorus-build-sealed-secrets charts/sealed-secrets -n kube-system
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

# deploy the ApplicationSets
ls deployment/applicationset/applicationset-chorus-*.yaml | xargs -n 1 kubectl -n argocd apply -f

deploy the Projects
ls deployment/project/chorus-*.yaml | xargs -n 1 kubectl -n argocd apply -f

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
