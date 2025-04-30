#!/bin/bash

kubectl apply -n argocd -f ../argocd/project/chorus-build.yaml
kubectl apply -n argocd -f ../argocd/applicationset/applicationset-chorus-build.yaml
