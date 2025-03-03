#!/bin/bash

echo "Running post-delete cleanup for ArgoCD..."

# Delete CRDs
kubectl delete crd applications.argoproj.io || echo "applications.argoproj.io already deleted"
kubectl delete crd applicationsets.argoproj.io || echo "applicationsets.argoproj.io already deleted"
kubectl delete crd appprojects.argoproj.io || echo "appprojects.argoproj.io already deleted"

echo "Post-delete cleanup completed."
