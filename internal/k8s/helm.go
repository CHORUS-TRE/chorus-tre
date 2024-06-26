package k8s

import (
	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/chart/loader"
)

// DeployHelmChart deploys a helm chart to a Kubernetes cluster
func DeployHelmChart(actionConfig *action.Configuration, releaseName string, chartPath string, namespace string) error {
	chart, err := loader.Load(chartPath)
	if err != nil {
		return err
	}

	client := action.NewInstall(actionConfig)
	client.ReleaseName = releaseName
	client.Namespace = namespace

	if _, err := client.Run(chart, chart.Values); err != nil {
		return err
	}
	return nil
}
