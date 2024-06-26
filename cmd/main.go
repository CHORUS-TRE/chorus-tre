package main

import (
	"log"
	"os"

	"github.com/urfave/cli/v2"
	"helm.sh/helm/v3/pkg/action"
	"helm.sh/helm/v3/pkg/chart/loader"
	"k8s.io/cli-runtime/pkg/genericclioptions"
)

func main() {
	app := &cli.App{
		Name:  "chorus",
		Usage: "deploy CHORUS on Kubernetes",
		Action: func(cCtx *cli.Context) error {
			return DeployChorus(cCtx.String("kubeconfig"), cCtx.String("release"), cCtx.String("namespace"))
		},
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "kubeconfig",
				Aliases: []string{"k"},
				Value:   "~/.kube/config",
				Usage:   "Path to the kubeconfig file",
			},
			&cli.StringFlag{
				Name:    "release",
				Aliases: []string{"c"},
				Value:   "chorus",
				Usage:   "Path to the helm chart",
			},
			&cli.StringFlag{
				Name:    "namespace",
				Aliases: []string{"n"},
				Value:   "default",
				Usage:   "Kubernetes namespace",
			},
		},
	}

	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}

func DeployChorus(kubeconfigPath string, releaseName string, namespace string) error {
	// TODO: check if chart exists
	err := DeployHelmChart(kubeconfigPath, releaseName, "charts/argo-cd", namespace) // use argo-cd chart for now to test
	if err != nil {
		return err
	}
	return nil
}

// DeployHelmChart deploys a helm chart to a Kubernetes cluster
func DeployHelmChart(kubeconfigPath string, releaseName string, chartPath string, namespace string) error {
	chart, err := loader.Load(chartPath)
	if err != nil {
		return err
	}

	actionConfig := new(action.Configuration)
	if err := actionConfig.Init(
		&genericclioptions.ConfigFlags{
			Namespace: &namespace, //TODO: check if this is correct
		},
		namespace,
		os.Getenv("HELM_DRIVER"),
		log.Printf,
	); err != nil {
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
