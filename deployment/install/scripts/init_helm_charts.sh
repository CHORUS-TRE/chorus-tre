#!/bin/bash

debug=false
if [[ "$1" == "--debug" ]]; then
  set -x
  shift
  debug=true
fi

echo "Pulling the Helm charts needed by the Terraform scripts "\
"and copying over their versions..."
echo "(Use the '--debug' option to see the full trace)"

header_msg="/* This file was automatically generated
by $0
DO NOT modify manually
Any change will be overwritten
*/"
tf_file_template="charts_versions.tftpl"
tf_file="charts_versions.tf"
touch $tf_file && echo "$header_msg" > $tf_file
sed '/\/\*/,/\*\//d' $tf_file_template  >> $tf_file

chart_rel_path="../../charts"
tf_variable_names=$(grep 'variable ' "$tf_file" | sed 's/variable "\([^"]*\)".*/\1/')

for var in $tf_variable_names; do
    # Extract chart name
    # from terraform variable name
    chart_name="${var/_version/}"
    chart_name="${chart_name//_/-}"
    echo -e ".\t $chart_name"
    yaml_file="${chart_rel_path}/${chart_name}/Chart.yaml"
    # Check that yaml file exists
    if [[ ! -f "$yaml_file" ]]; then
        echo -e "\t $chart_name → No input.yaml file."
        exit 1
    fi
    version=$(grep -E '^version:' "$yaml_file" | awk -F': ' '{print $2}')
    # Check that version value was found
    if [[ "$version" == "null" ]]; then
        echo -e "\t $chart → 'version' key not found."
        exit 1
    fi
    # Replace default Helm chart version
    sed -i '' -E "/variable \"$var\"[[:space:]]*\{/,/^\}/ s/(default[[:space:]]*=[[:space:]]*)\"[^\"]+\"/\1\"$version\"/" "$tf_file" || exit 1
    # Pull the chart
    if [[ $debug == true ]]; then
        cd $chart_rel_path/$chart_name && \
        helm dependency update $chart && \
        cd - || exit 1
    else
        cd $chart_rel_path/$chart_name && \
        helm dependency update $chart > /dev/null 2>&1  && \
        cd - > /dev/null 2>&1 || exit 1
    fi
done
echo "Done"