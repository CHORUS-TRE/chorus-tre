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

charts_path=$1
charts=$(find $charts_path -maxdepth 1 -mindepth 1 -type d)

for chart in $charts; do
    echo -e ".\t $(basename $chart)"
    # Pull the chart
    if [[ "$1" != "--no-pull" ]]; then
        pull_cmd="helm dependency update $chart"
        if [[ $debug == true ]]; then
            eval "$pull_cmd"
        else
            eval "$pull_cmd" > /dev/null 2>&1
        fi
    fi
done
echo "Done"