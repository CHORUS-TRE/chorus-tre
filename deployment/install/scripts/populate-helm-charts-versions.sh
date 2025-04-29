#!/bin/bash

tf_file="charts_versions.tf"
chart_rel_path="../../charts"
tf_variable_names=$(grep 'variable ' "$tf_file" | sed 's/variable "\([^"]*\)".*/\1/')

echo "Fetching Helm charts versions..."
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
done
echo "Done"