# Chorus Pod Priority Class Helm Chart

This Helm chart deploys Kubernetes PriorityClass resources to manage pod scheduling priorities in CHORUS.

## Overview

PriorityClasses enable you to assign importance levels to pods. Higher priority pods are scheduled before lower priority pods and can preempt (evict) lower priority pods when resources are scarce.

## Installation

```bash
helm install chorus-pod-priority-class ./charts/chorus-pod-priority-class
```

## Configuration

The chart provides several pre-configured priority classes that can be enabled/disabled individually:

| Priority Class | Value | Preemption Policy | Description |
|---|---|---|---|
| high-priority | 1000000 | PreemptLowerPriority | Important production workloads |
| medium-priority | 500000 | PreemptLowerPriority | Standard workloads |
| low-priority | 100000 | PreemptLowerPriority | Regular workloads |
| batch-priority | 50000 | PreemptLowerPriority | Batch jobs and background processing |
| preemptible | 10000 | Never | Preemptible workloads that won't preempt others |
| best-effort | -100 | Never | Lowest priority for best-effort workloads |

### Values

| Parameter | Description | Default |
|---|---|---|
| `priorityClasses[].name` | Name of the PriorityClass | - |
| `priorityClasses[].enabled` | Enable this PriorityClass | `true` |
| `priorityClasses[].value` | Priority value (higher = more important) | - |
| `priorityClasses[].globalDefault` | Use as default for pods without priorityClassName | `false` |
| `priorityClasses[].preemptionPolicy` | PreemptLowerPriority or Never | `PreemptLowerPriority` |
| `priorityClasses[].description` | Description of the priority class | - |

## Usage

To assign a priority class to a pod, add the `priorityClassName` field to your pod spec:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  priorityClassName: high-priority
  containers:
  - name: my-container
    image: my-image:latest
```

## Customization

You can customize the priority classes by modifying `values.yaml`:

```yaml
priorityClasses:
  - name: custom-priority
    enabled: true
    value: 500000
    globalDefault: false
    preemptionPolicy: PreemptLowerPriority
    description: "Custom priority for specific workloads"
```

## Notes

- Only one PriorityClass can have `globalDefault: true`
- Pods without a `priorityClassName` will use the global default if configured
- Priority classes with `preemptionPolicy: Never` won't preempt lower priority pods
