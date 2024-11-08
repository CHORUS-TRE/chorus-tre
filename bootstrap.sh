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

# Enable Helm dry-run mode.
#DRY_RUN="--dry-run"
DRY_RUN=""

# Enable debug mode
#DEBUG="--debug"
DEBUG=""

CLUSTER_NAME=chorus-build

# Let's Encrypt ACME server
#LETS_ENCRYPT_ACME_URL=https://acme-staging-v02.api.letsencrypt.org/directory
LETS_ENCRYPT_ACME_URL=

# Namespaces
NS_INGRESS=ingress-nginx
NS_CERTMANAGER=cert-manager
NS_ARGOCD=argocd
NS_HARBOR=harbor
NS_KEYCLOAK=keycloak

# Secrets
SECRET_ARGOCD_CACHE=argo-cd-cache-secret
SECRET_HARBOR_DB=harbor-db-secret
SECRET_HARBOR=harbor-secret
SECRET_KEYCLOAK_DB=keycloak-db-secret
SECRET_KEYCLOAK=keycloak-secret

# LetsEncrypt
CLUSTER_ISSUER=letsencrypt-prod

# Postgresql versions
POSTGRESQL_HARBOR=15.8.0
POSTGRESQL_KEYCLOAK=16.4.0

# Creating a namespace if it's not existing.
create_ns() {
    set +e
    kubectl get ns "$1" 2>&1 >/dev/null
    if [ 0 -ne $? ]
    then
        set -e
        kubectl create ${DRY_RUN} ns "$1"
    fi
    set -e
}

# Install Ingress-NGINX
helm dep update charts/ingress-nginx
helm upgrade --install ${CLUSTER_NAME}-ingress-nginx charts/ingress-nginx \
    -n "${NS_INGRESS}" \
    --create-namespace \
    --wait \
    ${DEBUG} ${DRY_RUN}

# install Cert-Manager
# in two steps:
# 1. get the CRDs;
# 2. create a cluster issuer
CERT_MANAGER_VERSION="$(grep -o "v[0-9]*\\.[0-9]*\\.[0-9]*" charts/cert-manager/Chart.lock)"
kubectl apply -f \
    https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml

helm dep update charts/cert-manager
helm upgrade --install ${CLUSTER_NAME}-cert-manager charts/cert-manager \
    -n "${NS_CERTMANAGER}" \
    --set "clusterissuer.name=${CLUSTER_ISSUER}" \
    --set "clusterissuer.email=${EMAIL}" \
    --set "clusterissuer.server=${LETS_ENCRYPT_ACME_URL}" \
    --wait \
    ${DEBUG} ${DRY_RUN}

# install our Self-Signed issuer for Postgres
# find the existing self-signed issuer to avoid recreating any.
set +o pipefail
self_signed=$(kubectl get clusterissuer --ignore-not-found | grep selfsigned- | awk '{ print $1 }')
set -o pipefail
if [ -e "${self_signed}" ]
then
    SELF_SIGNED_ISSUER="selfsigned-$(date +"%Y%m")"
else
    echo "Re-using the self-signed cluster-issuer found: ${self_signed}"
    SELF_SIGNED_ISSUER="$(echo -n $self_signed | sed -e 's/-cluster-issuer$//')"
fi

helm dep update charts/self-signed-issuer
helm upgrade --install ${CLUSTER_NAME}-self-signed-issuer charts/self-signed-issuer \
    -n "${NS_CERTMANAGER}" \
    --set "nameOverride=${SELF_SIGNED_ISSUER}" \
    --set clusterIssuers.0.name=private-ca-cluster-issuer \
    --wait \
    ${DEBUG} ${DRY_RUN}


# install Valkey/Redis for ArgoCD
# it requires a secret
# and we disable the "metrics" as prometheus crds aren't installed at this stage.
create_ns "${NS_ARGOCD}"

set +e
kubectl get -n ${NS_ARGOCD} secret "${SECRET_ARGOCD_CACHE}" 2>&1 >/dev/null
if [ 0 -ne $? ]
then
    set -e
    redis_password="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
    kubectl create secret generic \
        "${SECRET_ARGOCD_CACHE}" \
        -n "${NS_ARGOCD}" \
        --from-literal "redis-username=" \
        --from-literal "redis-password=${redis_password}" \
        ${DEBUG} ${DRY_RUN}
fi
set -e

helm dep udpate charts/valkey
helm upgrade --install ${CLUSTER_NAME}-argo-cd-cache charts/valkey \
    -n "${NS_ARGOCD}" \
    --set valkey.auth.enabled=true \
    --set valkey.auth.sentinel=false \
    --set "valkey.auth.existingSecret=${SECRET_ARGOCD_CACHE}" \
    --set valkey.auth.existingSecretPasswordKey=redis-password \
    --set valkey.metrics.enabled=false \
    --set valkey.metrics.serviceMonitor.enabled=false \
    --set valkey.metrics.podMonitor.enabled=false \
    --wait \
    ${DEBUG} ${DRY_RUN}

# install Argo CD
# it's using the above Valkey server (aka Redis).
helm dep update charts/argo-cd
helm upgrade --install ${CLUSTER_NAME}-argo-cd charts/argo-cd \
    -n "${NS_ARGOCD}" \
    --set argo-cd.redis.enabled=false \
    --set argo-cd.redisSecretInit.enabled=false \
    --set argo-cd.externalRedis.host=${CLUSTER_NAME}-argo-cd-cache-valkey-primary \
    --set argo-cd.externalRedis.existingSecret=${SECRET_ARGOCD_CACHE} \
    --set argo-cd.global.domain=argo-cd.build.$DOMAIN_NAME \
    --set "argo-cd.global.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/backend-protocol=HTTP" \
    --set "argo-cd.global.ingress.annotations.cert-manager\\.io/cluster-issuer=${CLUSTER_ISSUER}" \
    --set argo-cd.server.ingress.extraTls[0].hosts[0]=argo-cd.build.$DOMAIN_NAME \
    --set argo-cd.server.ingress.extraTls[0].secretName=argocd-ingress-http \
    --set "argo-cd.global.ingressGrpc.annotations.nginx\\.ingress\\.kubernetes\\.io/backend-protocol=GRPC" \
    --set "argo-cd.global.ingressGrpc.annotations.cert-manager\\.io/cluster-issuer=${CLUSTER_ISSUER}" \
    --set argo-cd.server.ingressGrpc.extraTls[0].hosts[0]=grpc.argo-cd.build.$DOMAIN_NAME \
    --set argo-cd.server.ingressGrpc.extraTls[0].secretName=argocd-ingress-grpc \
    --wait \
    ${DEBUG} ${DRY_RUN}

# install Keycloak
create_ns "${NS_KEYCLOAK}"

set +e
kubectl get -n ${NS_KEYCLOAK} secret "${SECRET_KEYCLOAK_DB}" 2>&1 >/dev/null
if [ 0 -ne $? ]
then
    set -e
    keycloak_db_password="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
    kubectl create secret generic \
        "${SECRET_KEYCLOAK_DB}" \
        -n "${NS_KEYCLOAK}" \
        --from-literal "postgres-password=postgres" \
        --from-literal "password=${keycloak_db_password}" \
        ${DRY_RUN}
fi

set +e
kubectl get -n ${NS_KEYCLOAK} secret "${SECRET_KEYCLOAK}" 2>&1 >/dev/null
if [ 0 -ne $? ]
then
    set -e
    keycloak_admin_password="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
    kubectl create secret generic \
        "${SECRET_KEYCLOAK}" \
        -n "${NS_KEYCLOAK}" \
        --from-literal "adminPassword=${keycloak_admin_password}" \
        ${DRY_RUN}
fi
set -e

helm upgrade --install ${CLUSTER_NAME}-keycloak-db charts/postgresql \
    -n "${NS_KEYCLOAK}" \
    --set postgresql.global.postgresql.auth.username=keycloak \
    --set postgresql.global.postgresql.auth.database=keycloak \
    --set postgresql.global.postgresql.auth.existingSecret=keycloak-db-secret \
    --set postgresql.tls.enabled=true \
    --set postgresql.tls.certificatesSecret=keycloak-db-tls-secret \
    --set postgresql.primary.persistence.size=1Gi \
    --set postgresql.image.registry=docker.io \
    --set postgresql.image.repository=bitnami/postgresql \
    --set postgresql.image.tag=${POSTGRESQL_KEYCLOAK} \
    --set postgresql.metrics.enabled=false \
    --set postgresql.metrics.serviceMonitor.enabled=false \
    --set certificate.enabled=true \
    --set certificate.secretName=keycloak-db-tls-secret \
    --set certificate.issuerRef.name=private-ca-cluster-issuer \
    --set certificate.issuerRef.kind=ClusterIssuer \
    --wait \
    ${DEBUG} ${DRY_RUN}

helm dep update charts/keycloak
helm upgrade --install ${CLUSTER_NAME}-keycloak charts/keycloak \
    -n "${NS_KEYCLOAK}" \
    --set keycloak.nameOverride=keycloak \
    --set keycloak.auth.existingSecret=keycloak-secret \
    --set keycloak.auth.passwordSecretKey=adminPassword \
    --set keycloak.tls.enabled=true \
    --set keycloak.tls.existingSecreta=keycloak-tls-secret \
    --set keycloak.ingress.servicePort=https \
    --set keycloak.ingress.hostname=auth.build.${DOMAIN_NAME} \
    --set keycloak.ingress.annotations.cert-manager\\.io/cluster-issuer=${CLUSTER_ISSUER} \
    --set keycloak.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/backend-protocol=HTTPS \
    --set keycloak.adminIngress.enabled=false \
    --set keycloak.externalDatabase.host=${CLUSTER_NAME}-keycloak-db-postgresql \
    --set keycloak.externalDatabase.user=keycloak \
    --set keycloak.externalDatabase.database=keycloak \
    --set keycloak.externalDatabase.existingSecret=keycloak-db-secret \
    --set keycloak.externalDatabase.existingSecretPasswordKey=password \
    --set keycloak.postgresql.enabled=false \
    --set keycloak.metrics.enabled=false \
    --set keycloak.metrics.serviceMonitor.enavbled=false \
    --set certificate.enabled=true \
    --set certificate.secretName=keycloak-tls-secret \
    --set certificate.issuerRef.name=private-ca-cluster-issuer \
    --set certificate.issuerRef.kind=ClusterIssuer \
    --wait \
    ${DEBUG} ${DRY_RUN}


# install Harbor
create_ns "${NS_HARBOR}"

set +e
kubectl get -n ${NS_HARBOR} secret "${SECRET_HARBOR_DB}" 2>&1 >/dev/null
if [ 0 -ne $? ]
then
    set -e
    harbor_db_password="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
    kubectl create secret generic \
        "${SECRET_HARBOR_DB}" \
        -n "${NS_HARBOR}" \
        --from-literal "postgres-password=postgres" \
        --from-literal "password=${harbor_db_password}" \
        ${DRY_RUN}
fi

set +e
kubectl get -n ${NS_HARBOR} secret "${SECRET_HARBOR}" 2>&1 >/dev/null
if [ 0 -ne $? ]
then
    set -e
    harbor_secret="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
    harbor_secret_key="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
    harbor_csrf_key="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
    harbor_admin_password="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
    harbor_jobservice_secret="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
    harbor_registry_passwd="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
    harbor_registry_htpasswd="$(htpasswd -nb admin "${harbor_registry_passwd}")"
    harbor_registry_http_secret="$(python -c 'import secrets; print(secrets.token_urlsafe(32))')"
    kubectl create secret generic \
        "${SECRET_HARBOR}" \
        -n "${NS_HARBOR}" \
        --from-literal "secret=${harbor_secret}" \
        --from-literal "secretKey=${harbor_secret_key}" \
        --from-literal "CSRF_KEY=${harbor_csrf_key}" \
        --from-literal "HARBOR_ADMIN_PASSWORD=${harbor_admin_password}" \
        --from-literal "JOBSERVICE_SECRET=${harbor_jobservice_secret}" \
        --from-literal "REGISTRY_PASSWD=${harbor_registry_passwd}" \
        --from-literal "REGISTRY_HTPASSWD=${harbor_registry_htpasswd}" \
        --from-literal "REGISTRY_HTTP_SECRET=${harbor_registry_http_secret}" \
        ${DRY_RUN}
fi

set -e
# install Valkey/Redis for Harbor
helm upgrade --install ${CLUSTER_NAME}-harbor-cache charts/valkey \
    -n "${NS_HARBOR}" \
    --create-namespace \
    --set valkey.auth.enabled=false \
    --set valkey.auth.sentinel=false \
    --set valkey.metrics.enabled=false \
    --set valkey.metrics.serviceMonitor.enabled=false \
    --set valkey.metrics.podMonitor.enabled=false \
    --wait \
    ${DEBUG} ${DRY_RUN}

# install Postgresql for Harbor
helm dep update charts/postgresql
helm upgrade --install ${CLUSTER_NAME}-harbor-db charts/postgresql \
    -n "${NS_HARBOR}" \
    --set postgresql.global.postgresql.auth.username=harbor \
    --set postgresql.global.postgresql.auth.existingSecret=harbor-db-secret \
    --set postgresql.tls.enabled=true \
    --set postgresql.tls.certificatesSecret=harbor-db-tls-secret \
    --set "postgresql.primary.initdb.scripts.initial-registry\\.sql=CREATE DATABASE registry ENCODING 'UTF-8'; \\c registry; CREATE TABLE schema_migrations(version bigint not null primary key\\, dirty boolean no null);" \
    --set postgresql.primary.persistence.size=10Gi \
    --set postgresql.primary.resourcePreset=small \
    --set postgresql.image.registry=docker.io \
    --set postgresql.image.repository=bitnami/postgresql \
    --set postgresql.image.tag=${POSTGRESQL_HARBOR} \
    --set postgresql.metrics.enabled=false \
    --set postgresql.metrics.serviceMonitor.enabled=false \
    --set certificate.enabled=true \
    --set certificate.secretName=harbor-db-tls-secret \
    --set certificate.issuerRef.name=private-ca-cluster-issuer \
    --set certificate.issuerRef.kind=ClusterIssuer \
    --wait \
    ${DEBUG} ${DRY_RUN}

helm dep update charts/harbor
helm upgrade --install ${CLUSTER_NAME}-harbor charts/harbor \
    -n "${NS_HARBOR}" \
    --set harbor.expose.tls.certSource=secret \
    --set harbor.export.tls.secret.secretName=harbor.build.${DOMAIN_NAME}-tls \
    --set harbor.ingress.hosts.core=harbor.build.${DOMAIN_NAME} \
    --set harbor.externalURL=https://harbor.build.${DOMAIN_NAME} \
    --set harbor.database.external.host=${CLUSTER_NAME}-harbor-db-postgresql \
    --set harbor.redis.external.addr=${CLUSTER_NAME}-harbor-cache-valkey-primary:6379 \
    --set harbor.metrics.enabled=false \
    --set harbor.metrics.serviceMonitor.enavbled=false \
    --set certificate.enabled=true \
    --set certificate.issuerRef.name=private-ca-cluster-issuer \
    --set certificate.issuerRef.kind=ClusterIssuer \
    --wait \
    ${DEBUG} ${DRY_RUN}

# install sealed-secrets
helm dep update charts/sealed-secrets
helm upgrade --install ${CLUSTER_NAME}-sealed-secrets charts/sealed-secrets \
    -n kube-system \
    --wait \
    ${DEBUG} ${DRY_RUN}

# get argocd initial password
echo "ArgoCD username: admin"
echo -n "ArgoCD password: "
kubectl -n ${NS_ARGOCD} get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo -e "\n"

# display ArgoCD URL
echo -e "ArgoCD is available at: https://argo-cd.build.$DOMAIN_NAME\n"

# display OCI Registry URL
echo -e "OCI Registry is available at: https://harbor.build.$DOMAIN_NAME\n"

# deploy the ApplicationSets
ls deployment/applicationset/applicationset-chorus-*.yaml | xargs -n 1 kubectl -n argocd apply -f

# deploy the Projects
ls deployment/project/chorus-*.yaml | xargs -n 1 kubectl -n argocd apply -f

# display DNS records
ARGOCD_EXTERNAL_IP=$(kubectl -n ${NS_ARGOCD} get ingress ${CLUSTER_NAME}-argo-cd-argocd-server -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
GRPC_ARGOCD_EXTERNAL_IP=$(kubectl -n ${NS_ARGOCD} get ingress ${CLUSTER_NAME}-argo-cd-argocd-server-grpc -o jsonpath="{.status.loadBalancer.ingress[0].ip}")
REGISTRY_EXTERNAL_IP=$(kubectl -n ${NS_HARBOR} get ingress ${CLUSTER_NAME}-harbor-ingress -o jsonpath="{.status.loadBalancer.ingress[0].ip}")

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
