package k8s

import (
	"log"
	"os"
	"os/user"

	"helm.sh/helm/v3/pkg/action"
	"k8s.io/cli-runtime/pkg/genericclioptions"
)

// FindKubeconfig returns the path to the kubeconfig file
func FindKubeconfig(kubeconfigPath string) string {
	// TODO: replace ~ by home dir if specified in kubeconfigPath
	if kubeconfigPath == "" {
		kubeconfigPath = os.Getenv("KUBECONFIG")
		if kubeconfigPath == "" {
			usr, _ := user.Current()
			kubeconfigPath = usr.HomeDir + "/.kube/config"
		}
	}
	return kubeconfigPath
}

// LoadActionConfig loads the action configuration
func LoadActionConfig(kubeconfigPath string, namespace string) (*action.Configuration, error) {
	clientGetter := genericclioptions.NewConfigFlags(false)
	clientGetter.KubeConfig = &kubeconfigPath
	clientGetter.Namespace = &namespace

	actionConfig := new(action.Configuration)
	if err := actionConfig.Init(
		clientGetter,
		namespace,
		os.Getenv("HELM_DRIVER"),
		log.Printf, // TODO: replace log.Printf by a custom logger to have something less verbose
	); err != nil {
		return nil, err
	}
	return actionConfig, nil
}
