#!/bin/bash

CERT_MANAGER_VERSION="$(grep -o "v[0-9]*\\.[0-9]*\\.[0-9]*" ../../charts/cert-manager/Chart.lock)"
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml
