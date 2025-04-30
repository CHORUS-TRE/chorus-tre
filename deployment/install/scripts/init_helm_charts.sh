#!/bin/bash
set -e

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
tf_chart_file_template="charts_versions.tftpl"
tf_chart_file="charts_versions.tf"

tf_crds_file_template="crds_versions.tftpl"
tf_crds_file="crds_versions.tf"

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

generate_from_template $tf_chart_file_template $tf_chart_file
generate_from_template $tf_crds_file_template $tf_crds_file

chart_rel_path="../../charts"
tf_chart_var_names=$(grep 'variable ' "$tf_chart_file" | sed 's/variable "\([^"]*\)".*/\1/')
tf_crds_var_names=$(grep 'variable ' "$tf_crds_file" | sed 's/variable "\([^"]*\)".*/\1/')

for chart_var in $tf_chart_var_names; do
    # Extract chart name
    # from terraform variable name
    chart_name="${chart_var/_version/}"
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
    sed -i '' -E "/variable \"$chart_var\"[[:space:]]*\{/,/^\}/ s/(default[[:space:]]*=[[:space:]]*)\"[^\"]+\"/\1\"$chart_version\"/" "$tf_chart_file"
    # Copy over the CRDs version if needed
    for crds_var in $tf_crds_var_names; do
        if [[ $crds_var == "${chart_var/_version/}"* ]]; then
            crds_version="$(grep -o "[0-9]*\\.[0-9]*\\.[0-9]*" $chart_rel_path/$chart_name/Chart.lock)"
            check_version_non_null $crds_version
            sed -i '' -E "/variable \"$crds_var\"[[:space:]]*\{/,/^\}/ s/(default[[:space:]]*=[[:space:]]*)\"[^\"]+\"/\1\"$crds_version\"/" "$tf_crds_file"
            break
        fi
    done
    # Pull the chart
    if [[ $debug == true ]]; then
        cd $chart_rel_path/$chart_name && \
        helm dependency update $chart && \
        cd -
    else
        cd $chart_rel_path/$chart_name && \
        helm dependency update $chart > /dev/null 2>&1  && \
        cd - > /dev/null 2>&1
    fi
done
echo "Done"