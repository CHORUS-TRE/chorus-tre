#!/bin/bash
set -e

debug=false
if [[ "$1" == "--debug" ]]; then
  set -x
  shift
  debug=true
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "This script pulls the Helm charts needed by the Terraform scripts"
    echo "Use the '--debug' option to see the full trace"
    echo "Use the '--no-pull' option to prevent pulling the charts"
    exit 0
fi

echo "Pulling the Helm charts needed by the Terraform scripts"

chart_rel_path="../../charts"
chart_names='ingress-nginx cert-manager argo-cd valkey keycloak postgresql'

for chart_name in $chart_names; do
    echo -e ".\t $chart_name"
    # Pull the chart
    if [[ "$1" != "--no-pull" ]]; then
        #pull_cmd="cd $chart_rel_path/$chart_name && helm dependency update && cd -"
        pull_cmd="helm dependency update $chart_rel_path/$chart_name"
        if [[ $debug == true ]]; then
            eval "$pull_cmd"
        else
            eval "$pull_cmd" > /dev/null 2>&1
        fi
    fi
done
echo "Done"