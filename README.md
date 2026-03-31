Grafana Stack on Kubernetes
===========================
v26.01.10

Copyright (c)2025-2026 Timothy C. Arland <tcarland at gmail dot com>

Steps for customizing and deploying the [Grafana](https://grafana.com)
Ecosystem, consisting of Loki, Grafana, Tempo, and Mimir; the (LGTM) stack.
This project also includes deploying the [Prometheus](https://prometheus.io)
Community chart.


# Table of Contents

- [Grafana Stack on Kubernetes](#grafana-stack-on-kubernetes)
  * [Overview](#overview)
    + [Components Matrix](#components-matrix)
    + [Architecture and Documentation](#architecture-and-documentations)
    + [Requirements](#requirements)
    + [Deployment Configuration](#deployment-configuration)
    + [S3 Buckets](#s3-buckets)
  * [Mimir](#mimir)
  * [Prometheus Operator and Grafana](#prometheus-operator-and-grafana)
    + [Prometheus and Grafana Ingress](#prometheus-and-grafana-ingress)
  * [Loki](#loki)
    + [Loki Ingress](#loki-ingress)
  * [Tempo](#tempo)
  * [Alloy](#alloy)
    + [Ansible Deployment](#ansible-deployment)
  * [Additional Document References](#additional-document-references)
  * [Additional Notes](#additional-notes)

<br>

---

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

|       **Component**                                |  **Version**  | **Helm Chart** | Chart Location |
| -------------------------------------------------- | ------------- | -------------- | -------- |
| [Mimir](https://github.com/grafana/mimir)          | **v3.0.4**    |    *6.0.6*     | source repo  |
| [Kube-Prometheus-Stack](https://github.com/prometheus-community/helm-charts) | **v3.10.0**  |  *82.15.1* |  at link |
| [Grafana](https://github.com/grafana/grafana)      | **v12.3.1**   |   *10.5.15*    | https://github.com/grafana-community/helm-charts |
| [Loki](https://github.com/grafana/loki)            | **v3.6.7**    |    *6.55.0*    | source repo |
| [Tempo](https://github.com/grafana/tempo)          | **v2.10.3**   |    *2.6.5*     | https://github.com/grafana-community/helm-charts |
| [Alloy](https://github.com/grafana/alloy)          | **v1.12.2**   |    *1.6.2*     | source repo |

<br>

## Architecture and Documentation

Each component in the stack uses a distributed set of microservices running as pods 
in Kubernetes. Refer to the official Grafana documentation for each component for 
details of the internal architecture.

- [Loki](https://grafana.com/docs/loki/latest/get-started/architecture/)
- [Grafana](https://grafana.com/docs/grafana/latest/fundamentals/)
- [Tempo](https://grafana.com/docs/tempo/latest/introduction/architecture/)
- [Mimir](https://grafana.com/docs/mimir/latest/get-started/about-grafana-mimir-architecture/)
- [Alloy](https://grafana.com/docs/alloy/latest/)

<br>

## Requirements

- [kustomize](https://github.com/kubernetes-sigs/kustomize) : v5.8.0
- [helm](https://github.com/helm/helm) : v3.19.0
- [yq](https://github.com/mikefarah/yq) : v4.47.2
- [mc](https://github.com/minio/mc) : latest stable (if using MinIO)
- httpd-tools : system package

<br>

---

<br> 

## Deployment Configuration

The project makes use of an Environment configuration for defining 
various parameters and secrets used by the various components.

Each environment defines it's own configuration under a directory 
in `env`.  The project will ignore all configuration from being 
checked in, so the overlay of those secrets should be managed 
outside of this project.

Create an Environment Configuration from the template.
```sh
mkdir ./env/myenvname/
cp ./env/env.template !$/myenvname/myenvname.env
# set configuration and secrets in myenvname.env
```

### Namespace
The default namespace for the stack is `monitoring`. If a different
namespace is desired, update the *base/kustomization.yaml* files
or create overlays as needed.

### Helm Charts
The project uses *kustomize* to wrap the management and use of Helm charts.
As a result *kustomize* requires the `--enable-helm` command switch when 
running *build*. This can become tedious, so a *bash* function and alias 
are provided to automatically detect the use of the helm wrapper and will 
automatically add the switch when running kustomize.
```sh
source env/kustom.sh
```

### Node labels
The *Prometheus Community Chart* includes *kube-state-metrics* and other 
k8s ecosystem components, and some *DaemonSets* or others are configured 
to run on worker nodes and contain a `node-selector` stanza.  Ensure the 
worker nodes are labeled accordingly.
```sh
$ k get nodes
NAME                   STATUS   ROLES           AGE    VERSION
dev-control-plane      Ready    control-plane   3d4h   v1.32.5
dev-control-plane2     Ready    control-plane   3d4h   v1.32.5
dev-control-plane3     Ready    control-plane   3d4h   v1.32.5
dev-worker             Ready    worker          3d4h   v1.32.5
dev-worker2            Ready    worker          3d4h   v1.32.5
dev-worker3            Ready    worker          3d4h   v1.32.5
dev-worker4            Ready    worker          3d4h   v1.32.5
dev-worker5            Ready    worker          3d4h   v1.32.5
dev-worker6            Ready    worker          3d4h   v1.32.5
```

Label cluster 'worker' nodes:
```sh
nodes=$(kubectl get nodes --no-headers | \
        awk '{ if($2 == "Ready" && $3 !~ /control/) { print $1 } }')
for n in $nodes; do
    kubectl label node $n node-role.kubernetes.io/worker=;
done
```

<br>

## S3 Buckets

The necessary buckets are scraped from the generated helm *values* files and
created via `mc mb` or alternatively `aws s3`. If neither tool is available,
the buckets needed are displayed and must be manually created prior to applying
manifests.
```sh
./bin/grafana-stack-setup.sh dev
-> Found Minio Client first, using 'mc mb dev/'...
 -> Ingress controller type set to 'istio'
 -> Creating Loki values from template
   -> Using Loki distributed chart
   -> Copying Loki ingress certificates
 -> Creating s3 secrets.env for Mimir
 -> Creating Prom/Grafana values from templates
   -> Copying Grafana ingress certs
   -> Copying Prometheus ingress certs
 -> Creating Tempo values from template
   -> Copying Tempo ingress certs
 -> Alloy config from template
 -> Needed S3 Buckets:
mimir-dev-alertmanager
mimir-dev-blocks
mimir-dev-ruler
loki-dev-chunk
loki-dev-ruler
loki-dev-admin
tempo-dev-traces
```

When testing or re-running the setup script frequently, subsequent runs
of the create s3 buckets can be skipped by setting the var *S3_SKIP_CREATE*.
```bash
export S3_SKIP_CREATE=true
```

<br>

---


# Mimir

Mimir acts as distributed metric storage and is core to the stack, so is the 
first component installed from the LGTM stack.

First fetch the chart prior to the install.
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

## Mimir Ingress

Metrics can be sent to *Mimir* via *Prometheus* or direct to *Mimir*, though 
the project is currently defaulting to only exposing Prometheus externally.
This can be changed relatively easy following the same pattern as *Loki* 
or *Tempo* by enabling the *Mimir Gateway* and enabling Authentication for 
agents. Ingress manifests are *not* provided as a result of this but can be 
copied from *Loki* and updated to point to the *mimir-gateway* accordingly.

<br>

---
    
# Prometheus Operator 

The *Prometheus Operator* is installed via the community helm [chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

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
 
## Prometheus Ingress

Ingress resources are provided for *Istio* or *Nginx* (deprecated) and 
are configured when the environment configuration includes settings for 
*GRAFANA_DOMAINNAME*, *PROMETHEUS_DOMAINNAME* and *INGRESS_NAMESPACE*. 
This will also look for certificates in the `env/$envname/certs/` path 
and copy them to *ingress/$ingress/base* path where `$ingress` will be 
set to *nginx* or *istio* depending on the 
value of *INGRESS_NAMESPACE*. 
Note the setup scripts specifically look for filenames of *prometheus.crt*
and *prometheus.key*.
```sh
ingress="istio" # or nginx
kustomize build prometheus/ingress/$ingress/ | kubectl apply -f -
```

<br>

---

# Grafana 

Grafana follows our typical pattern for installation using *kustomize*.
Running `kustomize build grafana/` provides the standard, non-enterprise 
install.  If the license file is located in `env/$envname/files` then it 
is assumed that an *overlay* is created for applying the Grafana Enterprise
versions. If the overlay path does not yet exist, the setup script will 
seed an overlay using the envname and copy the example overlay as 
`grafana/overlays/$envname/kustomization.yaml` which sets the license 
secret and used the *Enterprise* image for the container.
```sh
kustomize build --enable-helm grafana/overlays/$envname/ | kubectl apply -f -
```

## Grafana Ingress

As for other components, there are ingress manifests for *Nginx* (deprecated) 
and *Istio* which will be configured by the setup script when *GRAFANA_DOMAINNAME* 
is defined along with *INGRESS_NAMESPACE*.
```sh
kustomize build grafana/ingress/$ingress/ | kubectl apply -f -
```

<br>

---

# Loki

Loki supports a few different deployment modes, *Simple-Scalable*
and *Distributed*.  The *distributed* chart deploys all services
as pods whereas *simple-scalable* focuses on scaling the main
components. This is controlled by setting the LOKI_DISTRIBUTED
variable.

Note that *distributed* is the recommneded path by Grafana. 

Recent versions of the chart configure a *podAntiAffinity* to 
force that components run on a separate host. In some smaller 
or virtualized clusters, this can cause an issue thus this is 
disabled by default in our values by setting `affinity: null`
for the components that define it. This can be removed or 
commented for larger production deployments where the requiremnts 
can be met.

Fetch the chart first for validation.
```sh
kustomize build --enable-helm loki | less
```

Install the chart via *kustomize*
```sh
kustomize build --enable-helm loki/ | kubectl apply -f -
```

## Loki Ingress

To ship logs to Loki from outside the K8s cluster we must expose the 
Loki Distributors via the *Loki Gateway* which acts as a load balancer
and endpoint for clients.

Ingress manifests for *Nginx* or *Istio* are provided as `loki/ingress/nginx`
and `loki/ingress/istio` respectively. The setup script looks for the 
configuration variable *LOKI_DOMAINNAME* and configures the correct ingress 
based on *INGRESS_NAMESPACE* as well as copying certificates from the envdir or 
`env/$envname/certs/loki.*`.  TLS Certificates should be in PEM format 
and named as `loki.crt` and `loki.key`.
```sh
kustomize build loki/ingress/$ingress/ | kubectl apply -f -
```

<br>

---

# Tempo

**Note that recent Tempo releases require Kubernetes 1.29+**

The current *Tempo* chart does not take S3 credentials from a secret
like Mimir, so a *values.template* is used to generate the input
for the Tempo chart. The setup script creates the *values* from the 
environment configuration.

Fetch the chart first for validation.
```sh
kustomize build --enable-helm tempo | less
```

Install the chart via *kustomize*
```sh
kustomize build --enable-helm tempo/ | kubectl apply -f -
```

# Tempo Ingress

Tempo primarily needs two ports ingressed, both http/2 based, though
both are intended to have TLS, first for standard *https* and the 
other port, 4317, for *grpc-otlp*. The ingress controller can forward 
these either directly to the *distributor* service, or use the 
*tempo-gateway*. The project defaults to the *tempo-gateway* for its 
ability to use authentication, where the agent credentials are used.

<br>

---

# Alloy

Hosts that are having *Alloy* provisioned locally will need the `gnupg` package.

The *Alloy* binary can be installed via RHEL or Debian package repositories or as a 
standalone binary.

*Grafana* has an [Ansible Collection](https://grafana.com/docs/alloy/latest/set-up/install/ansible/) 
that can be used to manage Alloy deployments, however it deploys the binary
as the `root` user. 

A playbook is provided as `alloy/ansible` that installs the *Alloy* binary 
as a service account user and group instead. Refer to the Alloy Ansible [Readme](alloy/ansible/README-ansible.md)

**Note** that the configured endpoints for Alloy all use a protocol designation (eg. https://)
except for *Tempo*, whose endpoints are only <SERVICE:PORT>.

As stated in the *Mimir* section, when collecting metrics, they can be routed to 
either *Prometheus* or directly to *Mimir*. Currently, the project has configured 
*Prometheus* to be exposed external to the cluster with Authentication for Alloy 
agents using the `prometheus.remote_write` endpoint. Internal to the cluster
we can route either way, but note that the endpoints have a different API path
respectively.

- Prometheus  :  http://prometheus/api/v1/write
- Mimir       :  http://mimir-distributor/api/v1/push


## Ansible Deployment

The *Ansible Playbook* provided performs the following steps:

- A service account or a local *alloy* user is created to allow the 
  system service to run as non-root. The deployed user should be added 
  to any groups necessary to gather metrics and read logs.
  ```sh
  sudo useradd --no-create-home --groups "adm,systemd-journal" --shell /bin/false alloy
  ```

- A default environment file is created to define the *Alloy* command 
  options as `/etc/default/alloy`.

- A configuration file is provided to capture logs and record system metrics.
  The default install dir is `/var/lib/alloy`.

- A *service* file is then added to `/etc/systemd/system` to allow 
  *systemd* to manage  the *Alloy* service.

- Alloy has a configuration reference [here](https://grafana.com/docs/alloy/latest/reference/)

<br>

---

# Additional Document References

|                            |                              |
| -------------------------- | ---------------------------- |
| Loki API Reference         | https://grafana.com/docs/loki/latest/reference/ |
| Installing with Istio      | https://grafana.com/docs/loki/latest/setup/install/istio/ |
| Log Retention              | https://grafana.com/docs/loki/latest/operations/storage/retention/ |
| Enterprise Logs enablement | https://grafana.com/docs/enterprise-logs/latest/setup/helm/#configure-your-gel-license |
| Alloy Config Scenarios     | https://github.com/grafana/alloy-scenarios |
| Prometheus Feature Flags   | https://prometheus.io/docs/prometheus/latest/feature_flags/ |
| Tempo CLI                  | https://grafana.com/docs/tempo/latest/operations/tempo_cli/ |
| Tempo Validation           | https://grafana.com/docs/tempo/latest/set-up-for-tracing/setup-tempo/test/set-up-test-app/ |

Note that much of the Loki documentation for OSS overlaps with the
Grafana Enterprise Logs, Metrics, Traces documentation for installation, but does have its own 
document overlay of enterprise enablement details.

<br>

---

# Additional Notes

## Grafana PVC

Ensure a policy of *Retain* is set on the PV. Usually inherited from 
the *StorageClass*. If the PVC was created with a default SC or is 
set to *Delete*, it can be changed accordingly.
```sh
pv=$(kubectl get pv | grep grafana | awk '{ print $1 }')
kubectl patch pv $pv -p '{"spec":{"persistentVolumeReclaimPolicy": "Retain"}}'
```

Once the Grafana deployment has been dropped, remove any existing `claimRef` 
from the PV and ensure PV is *Released*.
```sh
kubectl patch pv $pv -p '{"spec":{"claimRef": null}}'
```

Alternatively, set volumeName on the *pvc* manifest before deploying. This
would require a patch to the manifests (or overlay):
```yaml
spec:
  volumeName: grafana
  accessModes:
    - ReadWriteOnce
```

## Prometheus - Add Node Exporters

Note that job names should be unique within Prometheus.
```yaml
    additionalScrapeConfigs:
      - job_name: 'node_exporter_host'
        static_configs:
          - targets: ['<NODE_EXPORTER_IP_OR_HOSTNAME>:9100']
            labels:
              instance: '<NODE_EXPORTER_NAME>'
```

## Loki Notes

Some additional notes regarding [Loki](resources/loki-notes.md)

<br>

---
```
Created 2025.05.05
by Timothy C. Arland <tcarland at gmail dot com>
```
