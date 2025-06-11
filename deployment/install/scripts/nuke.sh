#!/bin/bash

cluster_name=chorus-build-t

# PROMETHEUS
kubie ns prometheus
kubectl delete deployment $cluster_name-prometheus-blackbox-exporter
kubectl delete ns prometheus
kubectl delete $(kubectl get crds -oname | grep coreos.com)

# TRIVY
kubie ns trivy-system
kubectl delete deployment $cluster_name-trivy-operator
kubectl delete ns trivy-system

# ARGOCD
kubie ns argocd
helm uninstall $cluster_name-argo-cd $cluster_name-argo-cd-cache
kubectl delete ns argocd
kubectl delete $(kubectl get crds -oname | grep argoproj.io)

# HARBOR
kubie ns harbor
helm uninstall $cluster_name-harbor $cluster_name-harbor-cache $cluster_name-harbor-db
kubectl delete ns harbor

# KEYCLOAK
kubie ns keycloak
helm uninstall $cluster_name-keycloak $cluster_name-keycloak-db
kubectl delete ns keycloak

# CERT-MANAGER
kubie ns cert-manager
helm uninstall $cluster_name-cert-manager $cluster_name-self-signed-issuer
kubectl delete ns cert-manager
kubectl delete $(kubectl get crds -oname | grep cert-manager.io)

# NGINX
kubie ns ingress-nginx
helm uninstall $cluster_name-ingress-nginx
kubectl delete ns ingress-nginx