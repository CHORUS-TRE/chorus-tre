#!/bin/bash
set -e

debug=false
if [[ "$1" == "--debug" ]]; then
  set -x
  shift
  debug=true
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "This script pushes the local Helm charts to the newly created remote repository"
    echo "Use the '--debug' option to see the full trace"
    exit 0
fi

charts_path=$1
remote_repository=$2
repo_username=$3
repo_password=$4

helm_reg_login_cmd="helm registry login oci://$remote_repository --username $repo_username --password $repo_password"
if [[ $debug == true ]]; then
    $helm_reg_login_cmd
else
    $helm_reg_login_cmd > /dev/null 2>&1
fi

packages_path=$(dirname "$(realpath $0)")/tmp
charts=$(find $charts_path -maxdepth 1 -mindepth 1 -type d)

for chart in $charts
do
    helm_package_cmd="helm package $chart -d $packages_path"
    if [[ $debug == true ]]; then
        $helm_package_cmd
    else
        $helm_package_cmd > /dev/null 2>&1
    fi
done

packages=$(find $packages_path -type f)

for package in $packages
do
    helm_push_cmd="helm push $package oci://$remote_repository/charts"
    if [[ $debug == true ]]; then
        $helm_push_cmd
    else
        $helm_push_cmd > /dev/null 2>&1
    fi
done

rm -r $packages_path