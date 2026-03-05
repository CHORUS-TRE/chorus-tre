# Argo CI

Continuous Integration using Argo Events and Argo Workflows.

## How does it work?

### Overview

[EventBus](./templates/eventbus.yaml) defines an Event bus for [Argo Events](../argo-events/) on which the [events from GitHub](./template/github-eventsource.yaml) will be published.

Each _repository_ defined in the `webhookEvents` ([values](./values.yaml)) creates a webhook entry in the GitHub repository which sends **all** events to.

```
GitHub Repository #1 -> Webhook endpoint #1 -.
                                              \
GitHub Repository #2 -> Webhook endpoint #2 ---+-> EventBus
                                              /
GitHub Repository #3 -> Webhook endpoint #3 -'
```

Various sensors are listening on the `EventBus` and will be consuming the _events_. Last time we tried, an _event_ can be consumed by one `Sensor` only. Then, the sensor performs various filtering to trigger the rightful template. E.g. the sensor of the [workbench-operator](./templates/build-workbench-operator.yaml).

```
            .-> Sensor #1 -> Workflow -> ...
           /
EventBus -+---> Sensor #2 -> Workflow -> WorkflowTemplate
           \
            '-> Sensor #3 -> Workflow -> ...
```

### In Details

```mermaid
graph LR
    subgraph GitHub["GitHub<br/>(github.com)"]
        App["GitHub App<br/>---<br/>Name: chorus-build-argo-workflows<br/>App ID: ••••••••<br/>Installation ID: ••••••••<br/>Private key: ••••••••"]
        PAT["Personal Access Token<br/>---<br/>Name: chorus-build-argo-workflows<br/>Token: ••••••••"]

        Repo1["Repository<br/>---<br/>Name: workbench-operator"]
        Repo2["Repository<br/>---<br/>Name: chorus-web-ui"]
        Repo3["Repository<br/>---<br/>Name: chorus-backend"]
        Repo4["Repository<br/>---<br/>Name: images"]

        WH1["Webhook<br/>---<br/>Repo: workbench-operator<br/>Secret: ••••••••"]
        WH2["Webhook<br/>---<br/>Repo: chorus-web-ui<br/>Secret: ••••••••"]
        WH3["Webhook<br/>---<br/>Repo: chorus-backend<br/>Secret: ••••••••"]
        WH4["Webhook<br/>---<br/>Repo: images<br/>Secret: ••••••••"]

        App -.-> Repo1
        App -.-> Repo2
        App -.-> Repo3
        App -.-> Repo4

        Repo1 ==> WH1
        Repo2 --> WH2
        Repo3 --> WH3
        Repo4 --> WH4
    end

    subgraph K8s["Kubernetes Cluster<br/>(argo namespace)"]
        Secret1["Secret<br/>---<br/>Name: chorus-build-argo-workflows-github-app<br/>Key: privateKey"]
        Secret2["Secret<br/>---<br/>Name: workbench-operator-webhook<br/>Key: webhookSecret"]
        Secret3["Secret<br/>---<br/>Name: chorus-build-argo-workflows-github-pat<br/>Keys: username, password<br/>Note: token is stored under password key, username is empty"]

        ES["Event Source<br/>---<br/>Name: chorus-build-chorus-ci-github<br/>URL: webhook.build.chorus-tre.ch<br/>Endpoint: /push-workbench-operator:12000"]
        EB["Event Bus<br/>---<br/>Name: chorus-build-chorus-ci-default<br/>Type: NATS JetStream"]
        Sensor["Sensor<br/>---<br/>Name: build-workbench-operator<br/>Action: Triggers workflows"]
        WF["Workflow<br/>---<br/>Name: ci-workbench-operator<br/>Git: PAT credentials"]

        Secret1 --> ES
        Secret2 --> ES
        Secret3 --> WF
        Secret1 -.-x|future: not yet supported<br/>will allow not relying on PAT| WF

        ES ==> EB
        EB ==> Sensor
        Sensor ==> WF
    end

    App -.->|store private key| Secret1
    WH1 -.->|store webhook secret| Secret2
    PAT -.->|store PAT| Secret3

    WH1 ==>|forward event via<br/>HTTP POST| ES
    ES -.->|manage webhook via<br/>GitHub API| WH1

    classDef github fill:#24292e,stroke:#fff,stroke-width:2px,color:#fff,white-space:nowrap
    classDef secret fill:#d97700,stroke:#333,stroke-width:2px,color:#fff,white-space:nowrap
    classDef eventsource fill:#00c851,stroke:#333,stroke-width:2px,color:#000,white-space:nowrap
    classDef eventbus fill:#9c27b0,stroke:#333,stroke-width:2px,color:#fff,white-space:nowrap
    classDef sensor fill:#ff4444,stroke:#333,stroke-width:2px,color:#fff,white-space:nowrap
    classDef workflow fill:#0d47a1,stroke:#333,stroke-width:2px,color:#fff,white-space:nowrap

    class App,Repo1,Repo2,Repo3,Repo4,WH1,WH2,WH3,WH4,PAT github
    class Secret1,Secret2,Secret3 secret
    class ES eventsource
    class EB eventbus
    class Sensor sensor
    class WF workflow
```

**_Note_** Names are only examples. You might see different values in your installation.

## Secrets

This chart requires several types of secrets for different purposes:

### 1. Docker Registry Credentials

**Purpose**: Push OCI images or Helm charts to a registry.
**Configuration**: `sensor.dockerConfig.secretName`
**Type**: `kubernetes.io/dockerconfigjson`

### 2. GitHub Authentication (Webhook Management)

The chart supports two authentication methods for managing webhooks on GitHub repositories:

#### Option A: GitHub App (Recommended)

**Configuration**:
```yaml
githubApp:
  enabled: true
  appID: "123456"
  installationID: "789012"
  privateKeySecret:
    name: "chorus-build-argo-workflows-github-app"
    key: "privateKey"

webhookEvents:
  - name: workbench-operator
    webhookSecretName: "workbench-operator-webhook"
    webhookSecretKey: "webhookSecret"
```

**Required Secrets**:

1. **GitHub App Private Key** (shared across all repositories)
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: chorus-build-argo-workflows-github-app
     namespace: argo
   type: Opaque
   stringData:
     privateKey: |
       -----BEGIN RSA PRIVATE KEY-----
       ... (GitHub App private key)
       -----END RSA PRIVATE KEY-----
   ```

2. **Webhook Secrets** (one per repository)
   ```yaml
   apiVersion: v1
   kind: Secret
   metadata:
     name: workbench-operator-webhook
     namespace: argo
   type: Opaque
   stringData:
     webhookSecret: "your-webhook-secret-here"
   ```

#### Option B: Personal Access Token (Legacy)

**Configuration**:
```yaml
githubApp:
  enabled: false

webhookEvents:
  - name: workbench-operator
    secretName: "chorus-ci-github-workbench-operator"
```

**Required Secret** (one per repository):
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: chorus-ci-github-workbench-operator
  namespace: argo
type: Opaque
stringData:
  token: "github_pat_..."        # GitHub PAT for webhook management
  secret: "webhook-secret-here"  # Webhook signature validation secret
```

**Migration Note**: To migrate from PAT to GitHub App, set `githubApp.enabled: true` and configure `webhookSecretName` for each webhook event. Leave `webhookSecretName` empty (`""`) for repositories not yet migrated.

### 3. Git Credentials (Workflow Operations)

**Purpose**: Clone repositories and publish commit statuses from workflows.
**Configuration**: `gitCredentials.secretName` (single shared PAT for all repositories)
**Legacy Configuration**: `githubSecrets` map (deprecated, use `gitCredentials` instead)

**Required Secret**:
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: chorus-build-argo-workflows-github-pat
  namespace: argo
type: Opaque
stringData:
  username: "x-access-token"     # GitHub convention for PAT authentication
  password: "github_pat_..."     # GitHub PAT with repo access
```

**Note**: Argo Workflows does not currently support GitHub App authentication for git artifacts. This requires a classic GitHub PAT. Once Argo Workflows adds native GitHub App support, this PAT can be replaced with GitHub App credentials.
