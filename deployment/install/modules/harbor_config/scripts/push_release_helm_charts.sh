#!/bin/bash
set -e

if [[ "$1" == "--debug" ]]; then
  set -x
  shift
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "This script pushes the Helm charts from a specific CHORUS-TRE release to the newly created remote repository"
    echo "Use the '--debug' option to see the full trace"
    exit 0
fi

revision=$1
remote_repository=$2
repo_username=$3
repo_password=$4
repo_name=chorus-tre

helm registry login oci://$remote_repository --username $repo_username --password $repo_password --insecure

start_path=$(pwd)
temp_folder_path=$(dirname "$(realpath $0)")/tmp
packages_path=$temp_folder_path/packages
if [ -d $temp_folder_path ]; then
    rm -rf $temp_folder_path
fi
mkdir -p $temp_folder_path

cd $temp_folder_path
git clone --no-checkout https://github.com/CHORUS-TRE/$repo_name.git
cd $repo_name && git checkout $revision
cd $start_path

charts_path=$temp_folder_path/$repo_name/charts
charts=$(find $charts_path -maxdepth 1 -mindepth 1 -type d)

for chart in $charts
do
    helm dependency update $chart
    helm package $chart -d $packages_path
done

packages=$(find $packages_path -type f)

for package in $packages
do
    helm push $package oci://$remote_repository/charts --insecure-skip-tls-verify
done

#rm -r $temp_folder_path