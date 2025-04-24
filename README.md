Grafana - Prometheus Stack Deploy
=================================

Steps for customizing and deploying the Grafana Ecosystem, including
the Mimir, Prometheus, Tempo, Loki and Grafana.

2025.04.24  Timothy C. Arland <tarland@trace3.com>

# Components

- Mimir
- Prometheus
- Grafana
- Loki
- Tempo


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

The following list of buckets should be provisioned prior to deployment.
- mimir-blocks
- mimir-ruler
- mimir-alertmanager
- tempo-traces

## Installing Mimir

Test or view manifests prior to install
```sh
kustomize build --enable-helm mimir/ | less
```

Similar to running the helm template command. Note that the *charts*
path is seeded after running `kustomize build`
```sh
helm template mimir ./base/charts/mimir-distributed-5.6.0/mimir-distributed \
-f base/mimir-values.yaml -f mimir-structuredConfig.yaml \
-n monitoring
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
kustomize build --enable-helm prometheus/ | k apply -f -
```

## Tempo

Note that recent Tempo releases require Kubernetes 1.29+
