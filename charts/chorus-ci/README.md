# Argo CI

Continuous Integration using Argo Events and Argo Workflows.

## How does it work?

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

## Secrets

In the values file, there are three kind of secrets.

1. `sensor.dockerConfig.secretConfig` a `kubernetes.io/dockerconfigjson` secret holding credentials to push OCI images or Helm charts to a registry.
2. `webhookEvents.*.secretName` a secret holding rights to manage the webhook on the GitHub repositories.
3. `githubSecrets` a secret to clone and publish commit statuses on the repositories.
