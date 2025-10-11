Grafana - Prometheus Stack Deploy
=================================
Created 2025.05.05
by Timothy C. Arland <tcarland at gmail dot com>


Steps for customizing and deploying the Grafana Ecosystem, consisting 
of Prometheus, and the Loki, Grafana, Tempo, and Mimir (LGTM) stack. 
This  repository serves as a means for cleaner handling of secrets and 
environment configuration requirements to automate *helm* values 
generation. Given the flexible pattern of handling various environment 
configurations with *kustomize*, the project uses the `--enable-helm` 
functionality of *kustomize* to manage environment overlays essentially 
combining the use of *kustomize* and *helm*.


# Components

|       **Component**                           |  **Version**  | **Helm Chart** |
| --------------------------------------------- | ------------- | -------------- |
| [Mimir](https://github.com/grafana/mimir)     |  **v2.17.x**  |                |
| [Kube-Prometheus-Stack]()                     |  **70.3.0**   |                |
| [Grafana](https://github.com/grafana/grafana) |  **11.5.2**   |                |
| [Loki](https://github.com/grafana/loki)       |  **3.5.5**    |   *6.42.0*     |
| [Tempo](https://github.com/grafana/tempo)     |  **1.38.2**   |                |


## Pre-Deployment Secrets

Create and/or source the appropriate environment variables for S3 credentials.
```sh
mkdir env/myenv/mysecrets.env
# set values in my-secrets.env
source my-secrets.env
```

The default namespace for the stack is `monitoring`. If a different
namespace is desired, update the *base/kustomization.yaml* files
or create overlays accordingly.

## S3 Buckets

The necessary buckets are scraped from the generated values files and 
created via `mc mb` or alternatively `aws s3 

# Installing Mimir

First fetch the chart for testing or viewing manifests prior to the install.
```sh
kustomize build --enable-helm mimir/ | less
```

This is similar to running the *helm* template command. Note that the
*charts* path is seeded after running `kustomize build`.
The equivalent helm command would be:
```sh
helm template mimir ./base/charts/mimir-distributed-5.6.0/mimir-distributed \
  -f base/mimir-values.yaml \
  -f mimir-structuredConfig.yaml \
  -n monitoring
```

Install by outputting to *kubectl*
```sh
kustomize build --enable-helm mimir/ | kubectl apply -f -
```

# Prometheus Operator

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

Prometheus *CRDs* are rather large, which forced moving them to a
separate chart. Kubectl (and Kustomize) do not directly account
for the large size from the client-size and will throw an error
when trying to directly apply the chart.  Instead, we directly
apply the *CRD* manifests.
```sh
cd prometheus/base/charts/kube-prometheus-stack-${prometheus_version}
kubectl apply -f kube-prometheus-stack/charts/crds/crds/ \
--force-conflicts=true \
--server-side=true
```

Install prometheus
```sh
kustomize build --enable-helm prometheus/ | kubectl apply -f -
```

Ingress resources are provided for *Istio* or *Nginx* and are
configured when the environment configuration includes environment
settings for `GRAFANA_DOMAINNAME` and `INGRESS_NAMESPACE`.


# Tempo

Note that recent Tempo releases require Kubernetes 1.29+

The tempo chart does not take S3 credentials from a secret like Mimir,
unfortunately, so a *values* template is used to generate the input
for the Tempo chart.
