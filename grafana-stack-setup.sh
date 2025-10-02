#!/usr/bin/env bash
#
# Timothy C. Arland <tcarland at gmail dot com>
PNAME=${0##*\/}
VERSION="v25.10.02"

binpath=$(dirname "$0")
project=$(dirname "$(realpath "$binpath")")

envname="$1"
ingress="nginx"

export S3_BUCKET_NAME=${S3_BUCKET_NAME:-"mimir/data"}
export S3_SKIP_VERIFY=${MINIO_TLS_INSECURE:-"true"}
export GRAFANA_NAMESPACE="${GRAFANA_NAMESPACE:-monitoring}"


s3_secrets="
S3_REGION=\${S3_REGION}
S3_ENDPOINT=\${S3_ENDPOINT}
S3_BUCKET_NAME=\${S3_BUCKET_NAME}
S3_ACCESS_KEY=\${S3_ACCESS_KEY}
S3_SECRET_KEY=\${S3_SECRET_KEY}
S3_SKIP_VERIFY=\${S3_SKIP_VERIFY}
"

# validation checks
if ! which helm >/dev/null 2>&1; then
    echo "$PNAME Error, required binary 'helm' not found in PATH." >&2
    exit 2
fi

if [ -z "$S3_ENDPOINT" ]; then
    echo "$PNAME Error, S3_ENDPOINT not defined." >&2
    exit 1
fi

if [[ -z "$S3_ACCESS_KEY" || -z "$S3_SECRET_KEY" ]]; then
    echo "$PNAME Error, S3 credentials not defined." >&2
    exit 1
fi

if [ -z "$envname" ]; then
    echo "$PNAME envname not provided"
    exit 1
fi

source env/${envname}/${envname}.env

# strip protocol from endpoint
if [[ "$S3_ENDPOINT" =~ "http" ]]; then
    export S3_ENDPOINT=${S3_ENDPOINT#*//}
fi

echo " -> Creating secrets.env for Mimir"
echo "$s3_secrets" | envsubst > mimir/base/secrets.env

if [[ "$INGRESS_NAMESPACE" =~ "istio" ]]; then
    ingress="istio"
fi

if [ -n "$GRAFANA_DOMAINNAME" ]; then
    echo " -> Ingress controller type set to '$ingress'"
    cat prometheus/${ingress}/base/params.env.template | envsubst > prometheus/${ingress}/base/params.env
    if [ -d env/${envname}/certs ]; then
        echo " -> Copy certs from 'env/$envname/certs/'"
        cp env/${envname}/certs/* prometheus/${ingress}/base/
    fi
fi

echo " -> Creating configurations from templates"
cat prometheus/base/prom-values.template.yaml | envsubst > prometheus/base/prom-values.yaml
cat prometheus/base/prom-addScrapeConfigs.template.yaml | envsubst > prometheus/base/prom-addScrapeConfigs.yaml
cat tempo/base/tempo-values.template.yaml | envsubst > tempo/base/tempo-values.yaml
echo " -> Finished."

exit 0
