# prometheus-probes

A Helm chart that deploys Prometheus Operator Probe resources for blackbox monitoring of CHORUS-TRE endpoints across multiple environments.

## Overview

This chart creates Kubernetes `Probe` custom resources (from prometheus-operator) that configure blackbox-exporter to monitor HTTP endpoints. It's designed for multi-environment deployments where you want to monitor the same services across dev, int, qa, and production environments.

## Prerequisites

- Kubernetes cluster with prometheus-operator CRDs installed
- kube-prometheus-stack (or prometheus-operator) deployed
- Blackbox exporter available in the cluster

## Configuration

### Parameters

| Parameter | Description | Required | Default |
|-----------|-------------|----------|---------|
| `prober.url` | Blackbox exporter service URL (global) | Yes | - |
| `prober.port` | Blackbox exporter service port (global) | No | `9115` |
| `prober.scheme` | Connection scheme to blackbox exporter | No | `http` |
| `prober.path` | Probe endpoint path | No | `/probe` |
| `environments[].name` | Environment name (used in probe naming and labels) | Yes | - |
| `environments[].targets` | List of URLs to monitor | Yes | - |

**Note:** Names ending with `-with-auth` will use the `http_401` module instead of `http_2xx`.
