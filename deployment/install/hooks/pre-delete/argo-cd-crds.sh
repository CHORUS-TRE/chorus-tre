#!/bin/bash

echo "Running pre-delete cleanup for ArgoCD..."

# Remove resource-policy annotation from CRDs
kubectl patch crd applications.argoproj.io -p '{"metadata":{"annotations":{"helm.sh/resource-policy":null}}}' || echo "No annotation to remove for applications.argoproj.io"
kubectl patch crd applicationsets.argoproj.io -p '{"metadata":{"annotations":{"helm.sh/resource-policy":null}}}' || echo "No annotation to remove for applicationsets.argoproj.io"
kubectl patch crd appprojects.argoproj.io -p '{"metadata":{"annotations":{"helm.sh/resource-policy":null}}}' || echo "No annotation to remove for appprojects.argoproj.io"

echo "Pre-delete cleanup completed."
