#!/bin/bash
set -e

debug=false
if [[ "$1" == "--debug" ]]; then
  set -x
  shift
  debug=true
fi

if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "This script pulls the Helm charts needed by the Terraform scripts "\
    "and copies over the chart and the app version"
    echo "Use the '--debug' option to see the full trace"
    echo "Use the '--no-pull' option to prevent pulling the charts"
    exit 0
fi

echo "Pulling the Helm charts needed by the Terraform scripts "\
"and copying over their versions..."

header_msg="/* This file was automatically generated
by $0
DO NOT modify manually
Any change will be overwritten
*/"
chart_file_template="chart_versions.tftpl"
chart_file="chart_versions.tf"

app_file_template="app_versions.tftpl"
app_file="app_versions.tf"

generate_from_template() {
    local file_template=$1
    local file=$2
    touch $file && echo "$header_msg" > $file
    sed '/\/\*/,/\*\//d' $file_template  >> $file
}

check_version_non_null() {
    local version=$1
    if [[ "$version" == "null" ]]; then
        echo -e "\t $version → 'version' key not found."
        exit 1
    fi
}

generate_from_template $chart_file_template $chart_file
generate_from_template $app_file_template $app_file

chart_rel_path="../../charts"
chart_var_names=$(grep 'variable ' "$chart_file" | sed 's/variable "\([^"]*\)".*/\1/')
app_var_names=$(grep 'variable ' "$app_file" | sed 's/variable "\([^"]*\)".*/\1/')

for chart_var in $chart_var_names; do
    # Extract chart name
    # from terraform variable name
    chart_name="${chart_var/_chart_version/}"
    chart_name="${chart_name//_/-}"
    echo -e ".\t $chart_name"
    yaml_file="${chart_rel_path}/${chart_name}/Chart.yaml"
    # Check that yaml file exists
    if [[ ! -f "$yaml_file" ]]; then
        echo -e "\t $chart_name → No input.yaml file."
        exit 1
    fi
    chart_version=$(grep -E '^version:' "$yaml_file" | awk -F': ' '{print $2}')
    # Check that version value was found
    check_version_non_null $chart_version

    # Replace default Helm chart version
    sed -i '' -E "/variable \"$chart_var\"[[:space:]]*\{/,/^\}/ s/(default[[:space:]]*=[[:space:]]*)\"[^\"]+\"/\1\"$chart_version\"/" "$chart_file"
    # Copy over the CRDs version if needed
    for app_var in $app_var_names; do
        if [[ $app_var == "${chart_var/_chart_version/}"* ]]; then
            app_version=$(grep -E '^appVersion:' "$yaml_file" | awk -F': ' '{print $2}')
            check_version_non_null $app_version
            sed -i '' -E "/variable \"$app_var\"[[:space:]]*\{/,/^\}/ s/(default[[:space:]]*=[[:space:]]*)\"[^\"]+\"/\1\"$app_version\"/" "$app_file"
            break
        fi
    done
    # Pull the chart
    if [[ "$1" != "--no-pull" ]]; then
        pull_cmd="cd $chart_rel_path/$chart_name && helm dependency update $chart && cd -"
        if [[ $debug == true ]]; then
            eval "$pull_cmd"
        else
            eval "$pull_cmd" > /dev/null 2>&1
        fi
    fi
done
echo "Done"