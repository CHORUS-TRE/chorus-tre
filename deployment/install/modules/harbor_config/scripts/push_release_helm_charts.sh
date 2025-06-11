#!/bin/bash
set -e

debug=false
if [[ "$1" == "--debug" ]]; then
  set -x
  shift
  debug=true
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "This script pushes the Helm charts from a specific CHORUS release to the newly created remote repository"
    echo "Use the '--debug' option to see the full trace"
    exit 0
fi

release_name=$1
remote_repository=$2
repo_username=$3
repo_password=$4
repo_name=chorus-tre

helm_reg_login_cmd="helm registry login oci://$remote_repository --username $repo_username --password $repo_password --insecure"
if [[ $debug == true ]]; then
    $helm_reg_login_cmd
else
    $helm_reg_login_cmd > /dev/null 2>&1
fi

temp_folder_path=$(dirname "$(realpath $0)")/tmp
packages_path=$temp_folder_path/packages
if [ -d $temp_folder_path ]; then
    rm -rf $temp_folder_path
fi
mkdir $temp_folder_path

cd $temp_folder_path
release_tar_file_name=$repo_name.tar.gz
dwnld_cmd="curl -L -o $release_tar_file_name https://github.com/CHORUS-TRE/$repo_name/archive/refs/tags/v$release_name.tar.gz"
if [[ $debug == true ]]; then
    $dwnld_cmd
else
    $dwnld_cmd > /dev/null 2>&1
fi
tar -xzf $release_tar_file_name

cd -
release_folder_name=$repo_name-$release_name
charts_path=$temp_folder_path/$release_folder_name/charts
charts=$(find $charts_path -maxdepth 1 -mindepth 1 -type d)

for chart in $charts
do
    pull_cmd="helm dependency update $chart"
    helm_package_cmd="helm package $chart -d $packages_path"
    if [[ $debug == true ]]; then
        $pull_cmd
        $helm_package_cmd
    else
        $pull_cmd > /dev/null 2>&1
        $helm_package_cmd > /dev/null 2>&1
    fi
done

packages=$(find $packages_path -type f)

for package in $packages
do
    helm_push_cmd="helm push $package oci://$remote_repository/charts --insecure-skip-tls-verify"
    if [[ $debug == true ]]; then
        $helm_push_cmd
    else
        $helm_push_cmd > /dev/null 2>&1
    fi
done

rm -r $packages_path