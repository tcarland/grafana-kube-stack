Grafana - Prometheus Stack Deployments
======================================
v25.10.12

Steps for customizing and deploying the Grafana Ecosystem, consisting
of Prometheus, Loki, Grafana, Tempo, and Mimir; the (LGTM) stack.

# Overview

This repository serves as a means for cleaner handling of secrets and
environment configuration requirements to automate *helm* values
generation.

Given the flexible pattern of handling various environment
configurations with *kustomize*, the project uses the `--enable-helm`
feature of *kustomize* to manage environment overlays combining the
use of *kustomize* and *helm*; essentially acting as a wrapper to the
official *Prometheus Community*  [helm charts](https://github.com/prometheus-community/helm-chart)

The [Prometheus-Community](https://github.com/prometheus-community) helm
chart `kube-prometheus-stack` is used to install *Prometheus*, which also
installs the `kube-state-metrics` and `grafana` charts.


## Components Matrix

|       **Component**                           |  **Version**  | **Helm Chart** |
| --------------------------------------------- | ------------- | -------------- |
| [Mimir](https://github.com/grafana/mimir)     |  **v2.15.x**  |    *5.6.0*     |
| [Kube-Prometheus-Stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)           |  **v3.2.1**   |      *70.3.0*          |
|  -> [Grafana](https://github.com/grafana/grafana) | **11.5.2**  |
| [Loki](https://github.com/grafana/loki)       |  **v3.5.5**    |   *6.42.0*    |
| [Tempo](https://github.com/grafana/tempo)     |   |   *1.38.2*    |


## Requirements

- [kustomize](https://github.com/kubernetes-sigs/kustomize) : v5.7.1
- [helm](https://github.com/helm/helm) : v3.18.6
- [yq](https://github.com/mikefarah/yq) : v4.47.2
- [mc](https://github.com/minio/mc) : latest stable

## Pre-Deployment Secrets

Create and/or source the appropriate environment variables for S3 credentials.
```sh
mkdir ./env/myenvname/
cp ./env/env.template !$/myenvname.env
# set secrets in myenvname.env
```

The default namespace for the stack is `monitoring`. If a different
namespace is desired, update the *base/kustomization.yaml* files
or create overlays accordingly.


## S3 Buckets

The necessary buckets are scraped from the generated values files and
created via `mc mb` or alternatively `aws s3`.


## Installing Mimir

First pre-fetch the chart for testing or viewing manifests prior to the install.
```sh
kustomize build --enable-helm mimir/ | less
```

This is similar to running the *helm* template command. Note that the
*charts* path is seeded after running `kustomize build` against `./mimir/`.

The equivalent helm command would be:
```sh
helm template mimir ./base/charts/mimir-distributed-5.6.0/mimir-distributed \
  -f base/mimir-values.yaml \
  -f mimir-structuredConfig.yaml \
  -n monitoring
```

Install by shipping the output to *kubectl*
```sh
kustomize build --enable-helm mimir/ | kubectl apply -f -
```


## Prometheus Operator

Note that the kustomize manifests make use of a *node-selector* for
targeting *worker* nodes. Typically, *control-plane* nodes are already
provisioned with the role *node-role.kubernetes.io/control-plane*, but
worker nodes often start with no role labels.

One can set the worker role on targeted nodes or all workers.
```bash
nodes=$(kubectl get nodes --no-headers | \
    awk '{ if($2 == "Ready" && $3 !~ /master/) { print $1 } }')
for n in $nodes; do
    kubectl label node $n node-role.kubernetes.io/worker=;
done
```

Ensure the charts are pulled to the local *charts* cache by running
*kustomize build* first.
```sh
kustomize build --enable-helm prometheus/
```

Prometheus *CRDs* are rather large (for helm), which has forced
moving them to a separate chart. Kubectl (and Kustomize) do not
directly account for the large size on the client-side of *kubectl*
and will throw an error when trying to directly apply the chart.
Instead, the *CRDs* are installed independently first.
```sh
cd prometheus/base/charts/kube-prometheus-stack-${prometheus_version}
kubectl apply -f kube-prometheus-stack/charts/crds/crds/ \
  --force-conflicts=true \
  --server-side=true
```

With CRDs applied, now install prometheus
```sh
kustomize build --enable-helm prometheus/ | kubectl apply -f -
```

## Ingress

Ingress resources are provided for *Istio* or *Nginx* and are
configured when the environment configuration includes
settings for `GRAFANA_DOMAINNAME` and `INGRESS_NAMESPACE`.


# Tempo

Note that recent Tempo releases require Kubernetes 1.29+

The tempo chart does not take S3 credentials from a secret like Mimir,
unfortunately, so a *values.template* is used to generate the input
for the Tempo chart.

Fetch the chart first for validation.
```sh
kustomize build --enable-helm tempo | less
```

Install the chart via *kustomize*
```sh
kustomize build --enable-helm tempo/ | kubectls apply -f -
```

---
```
Created 2025.05.05
by Timothy C. Arland <tcarland at gmail dot com>
```
