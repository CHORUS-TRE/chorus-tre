# Argocd

A Helm chart for Argo CD, a declarative, GitOps continuous delivery tool for Kubernetes.

## Required Secrets

### Repository credentials using a GitHub App

You can find the GitHub App ID on the app's setting page.
You can find your app's ID on the settings page for your GitHub App. For more information about navigating to the settings page for your GitHub App, see [Modifying a GitHub App registration](https://docs.github.com/en/apps/maintaining-github-apps/modifying-a-github-app-registration#navigating-to-your-github-app-settings).

You can find the GitHub App Installation ID in the URL of your [organization's GitHub Apps configuration page](https://stackoverflow.com/questions/74462420/where-can-we-find-github-apps-installation-id).

The private key should be generated after [creating the GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/managing-private-keys-for-github-apps).

```
apiVersion: v1
stringData:
  githubAppID: "your-github-app-id"
  githubAppInstallationID: "your-github-app-installation-id"
  githubAppPrivateKey: |
    -----BEGIN RSA PRIVATE KEY-----
    ...
    -----END RSA PRIVATE KEY-----
  url: https://github.com/your-organization-name/environments.git
kind: Secret
metadata:
  labels:
    argocd.argoproj.io/secret-type: repository
  name: environments-repocreds
  namespace: "your-argocd-namespace
type: Opaque
```

References:
- [GitHub App Credential](https://argo-cd.readthedocs.io/en/stable/user-guide/private-repositories/#github-app-credential)
