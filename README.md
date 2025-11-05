Grafana Stack on Kubernetes
===========================
v25.11.05

Steps for customizing and deploying the [Grafana](https://grafana.com)
Ecosystem, consisting of Loki, Grafana, Tempo, and Mimir; the (LGTM) stack.
This project also includes deploying the [Prometheus](https://prometheus.io)
Community chart.

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

```
                    ┌───────────────────────────────┐
                    │         Data Sources          │
                    │ ───────────────────────────── │
                    │ • Applications & Services     │
                    │ • Kubernetes Logs             │
                    │ • Prometheus Exporters        │
                    │ • Tracing Instrumentation     │
                    └──────────────┬────────────────┘
                                   │
             ┌─────────────────────┼─────────────────────┐
             │                     │                     │
             ▼                     ▼                     ▼
   ┌────────────────┐    ┌────────────────┐     ┌────────────────┐
   │     Loki       │    │     Mimir      │     │     Tempo      │
   │ (Logs Backend) │    │ (Metrics Store)│     │ (Traces Store) │
   └──────┬─────────┘    └──────┬─────────┘     └──────┬─────────┘
          │                     │                      │
          ▼                     ▼                      ▼
   ┌──────────────────────────────────────────────────────────┐
   │                    S3 (Object Storage)                   │
   │  - Loki chunks, index, and ruler data                    │
   │  - Mimir blocks (TSDB data)                              │
   │  - Tempo trace blocks (compact traces)                   │
   └──────────────────────────────────────────────────────────┘
          ▲                     ▲                      ▲
          │                     │                      │
   ┌──────┴──────────┐   ┌──────┴─────────┐     ┌──────┴──────────┐
   │     Caches      │   │     Caches     │     │     Caches      │
   │ (Memcached,     │   │ (Memcached,    │     │ (Memcached,     │
   │  Redis, etc.)   │   │  Redis, etc.)  │     │  Redis, etc.)   │
   └──────┬──────────┘   └──────┬─────────┘     └──────┬──────────┘
          │                     │                      │
          └──────────────┬──────┴──────────────┬───────┘
                         ▼                     ▼
                    ┌────────────────────────────────┐
                    │          Grafana UI            │
                    │────────────────────────────────│
                    │ • Unified visualization layer  │
                    │ • Dashboards for Logs, Metrics │
                    │   and Traces (correlated view) │
                    │ • Alerting and data queries    │
                    └────────────────────────────────┘
```
<br>

---

<br>

## Components Matrix

|       **Component**                                |  **Version**  | **Helm Chart** |
| -------------------------------------------------- | ------------- | -------------- |
| [Mimir](https://github.com/grafana/mimir)          | **v2.17.0**   |    *5.8.0*     |
| [Kube-Prometheus-Stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) | **v3.2.1**  |  *78.5.0*  |
|  -> [Prometheus](https://github.com/)              | **v3.7.2**    | --- |
|  -> [Grafana](https://github.com/grafana/grafana)  | **v12.2.0**   | --- |
| [Loki](https://github.com/grafana/loki)            | **v3.5.5**    |   *6.42.0*     |
| [Tempo](https://github.com/grafana/tempo)          | **v2.9.0**    |   *1.38.2*     |
| [Alloy](https://github.com/grafana/alloy)          | **v1.11.0*    |   *1.4.0*      |

<br>

## Architecture and Documentation

Each component in the stack uses a distributed set of microservices running as pods in Kubernetes.
Refer to the official Grafana documentation for each component for details of the internal architecture.

- [Loki](https://grafana.com/docs/loki/latest/get-started/architecture/)
- [Grafana](https://grafana.com/docs/grafana/latest/fundamentals/)
- [Tempo](https://grafana.com/docs/tempo/latest/introduction/architecture/)
- [Mimir](https://grafana.com/docs/mimir/latest/get-started/about-grafana-mimir-architecture/)
- [Alloy](https://grafana.com/docs/alloy/latest/)


## Requirements

- [kustomize](https://github.com/kubernetes-sigs/kustomize) : v5.7.1
- [helm](https://github.com/helm/helm) : v3.19.0
- [yq](https://github.com/mikefarah/yq) : v4.47.2
- [mc](https://github.com/minio/mc) : latest stable (if using MinIO)


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

The necessary buckets are scraped from the generated helm *values* files and
created via `mc mb` or alternatively `aws s3`. If neither tool is available,
the buckets needed are displayed and must be manually created prior to applying
manifests.

<br>

---

# Mimir

First pre-fetch the chart for testing or viewing manifests prior to the install.
```sh
kustomize build --enable-helm mimir/ | less
```

This is similar to running the *helm* template command. Note that the
*charts* path is seeded after running `kustomize build` against `./mimir/`.

The equivalent helm command would be:
```sh
helm template mimir ./base/charts/mimir-distributed-5.8.0/mimir-distributed \
  -f base/mimir-values.yaml \
  -f mimir-structuredConfig.yaml \
  -n monitoring
```

Install by shipping the output to *kubectl*
```sh
kustomize build --enable-helm mimir/ | kubectl apply -f -
```
<br>

---

# Prometheus Operator and Grafana

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

<br>

---

# Tempo

**Note that recent Tempo releases require Kubernetes 1.29+**

The current *Tempo* chart does not take S3 credentials from a secret
like Mimir, so a *values.template* is used to generate the input
for the Tempo chart.

Fetch the chart first for validation.
```sh
kustomize build --enable-helm tempo | less
```

Install the chart via *kustomize*
```sh
kustomize build --enable-helm tempo/ | kubectl apply -f -
```
<br>

---

# Loki

Loki supports a few different deployment modes, *Simple-Scalable*
and *Distributed*.  The *distributed* chart deploys all services
as pods whereas *simple-scalable* focuses on scaling the main
components. This is controlled by setting the LOKI_DISTRIBUTED
variable.

Fetch the chart first for validation.
```sh
kustomize build --enable-helm loki | less
```

Install the chart via *kustomize*
```sh
kustomize build --enable-helm loki/ | kubectl apply -f -
```

## Loki Document References

A collection of some important documentation links from the main
[Grafana Loki Documentation](https://grafana.com/docs/loki/latest/) repo.

- Loki Configuration and API References: https://grafana.com/docs/loki/latest/reference/
- Configuring Authentication: https://grafana.com/docs/loki/latest/operations/authentication/
- Installing with Istio: https://grafana.com/docs/loki/latest/setup/install/istio/
- Log Retention: https://grafana.com/docs/loki/latest/operations/storage/retention/
- Grafana Enterprise Logs enablement:  https://grafana.com/docs/enterprise-logs/latest/setup/helm/#configure-your-gel-license

Note that much of the Loki documentation for OSS overlaps with the 
[Grafana Enterprise Logs](https://grafana.com/docs/enterprise-logs/latest)
documentation.

<br>

---

<br>

# Notes

## Add node exporters

Note that job names should be uniquie within prom scrap configs
```yaml
      - job_name: 'node_exporter_host'
        static_configs:
          - targets: ['<NODE_EXPORTER_IP_OR_HOSTNAME>:9100']
            labels:
              instance: '<NODE_EXPORTER_NAME>'
```

<br>

---
```
Created 2025.05.05
by Timothy C. Arland <tcarland at gmail dot com>
```
