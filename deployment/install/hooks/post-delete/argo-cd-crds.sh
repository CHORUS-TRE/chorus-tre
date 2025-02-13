#!/bin/bash

echo "######### Deleting Argo CRDs #########"
kubectl delete crd appprojects.argoproj.io
kubectl delete crd applications.argoproj.io
kubectl delete crd applicationsets.argoproj.io
