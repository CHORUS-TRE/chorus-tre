package main

import (
	"log"
	"os"

	"github.com/urfave/cli/v2"
	"helm.sh/helm/v3/pkg/action"

	"chorus/internal/k8s"
)

func main() {
	app := &cli.App{
		Name:  "chorus",
		Usage: "deploy CHORUS on Kubernetes",
		Action: func(cCtx *cli.Context) error {
			kubeconfigPath := k8s.FindKubeconfig(cCtx.String("kubeconfig"))
			actionConfig, err := k8s.LoadActionConfig(kubeconfigPath, cCtx.String("namespace"))
			if err != nil {
				return err
			}
			return DeployChorus(actionConfig, cCtx.String("release"), cCtx.String("namespace"))
		},
		Flags: []cli.Flag{
			&cli.StringFlag{
				Name:    "kubeconfig",
				Aliases: []string{"k"},
				Value:   "",
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

func DeployChorus(actionConfig *action.Configuration, releaseName string, namespace string) error {
	// TODO: check if chart exists
	err := k8s.DeployHelmChart(actionConfig, releaseName+"-ingress-nginx", "charts/ingress-nginx", namespace) // use ingress-nginx chart for now to test
	if err != nil {
		return err
	}

	return nil
}
