#!/usr/bin/env bash
#
# Timothy C. Arland <tcarland at gmail dot com>
PNAME=${0##*\/}
VERSION="v25.11.07"

binpath=$(dirname "$0")
project=$(dirname "$(realpath "$binpath")")
envname="$1"
ingress="nginx"
s3cmd=
buckets=()


s3_secrets="
GRAFANA_ENV=\${GRAFANA_ENV}
S3_REGION=\${S3_REGION}
S3_ENDPOINT=\${S3_ENDPOINT}
S3_BUCKET_NAME=\${S3_BUCKET_NAME}
S3_ACCESS_KEY=\${S3_ACCESS_KEY}
S3_SECRET_KEY=\${S3_SECRET_KEY}
S3_SKIP_VERIFY=\${S3_SKIP_VERIFY}
"


function create_s3_buckets()
{
    local ary=("$@")
    local rt=0

    for b in ${ary[@]}; do
        echo "${s3cmd}${b}"
        ( ${s3cmd}${b} >/dev/null 2>&1 )
        rt=$?
        if [ $rt -gt 1 ]; then
            echo "Make bucket error..  $rt"
            break
        fi
    done
    return $rt
}

# ---------------------------------------

echo "$PNAME $VERSION"

# validation checks
if ! which helm >/dev/null 2>&1; then
    echo "$PNAME Error, required binary 'helm' not found in PATH." >&2
    exit 2
fi

if ! which yq >/dev/null 2>&1; then
    echo "$PNAME Error, required binary 'yq' not found in PATH." >&2
fi

if [ -z "$envname" ]; then
    echo "$PNAME Error, ENV name not provided" >&2
    exit 1
fi

source env/${envname}/${envname}.env

if [ -z "$S3_ENDPOINT" ]; then
    echo "$PNAME Error, S3_ENDPOINT not defined." >&2
    exit 1
fi

if [ -z "$GRAFANA_ENV" ]; then
    echo "$PNAME Error, GRAFANA_ENV not defined." >&2
    exit 1
fi

if [[ -z "$S3_ACCESS_KEY" || -z "$S3_SECRET_KEY" ]]; then
    echo "$PNAME Error, S3 credentials not defined." >&2
    exit 1
fi

# strip protocol from endpoint if defined
if [[ "$S3_ENDPOINT" =~ "http" ]]; then
    export S3_ENDPOINT=${S3_ENDPOINT#*//}
fi

# prefer minio client
if which mc >/dev/null 2>&1; then
    if [ -z "${MINIO_ALIAS}" ]; then
        echo "> MINIO_ALIAS is not set, configure it to use 'mc'"
    else
        echo "> Found Minio Client first, using 'mc mb ${MINIO_ALIAS}/'..."
        s3cmd="mc mb ${MINIO_ALIAS}/"
    fi
fi

# alternatively use aws cli
if [ -z "$s3cmd" ]; then
    if which aws >/dev/null 2>&1; then
        echo "> Found the AWS CLI, using 'aws s3 mb s3://'"
        s3cmd="aws s3 mb s3://"
    else
        echo "$PNAME Warning, no s3 client found, buckets will not be created." >&2
    fi
fi

# ---------------------------------------

export S3_SKIP_VERIFY=${S3_SKIP_VERIFY:-"false"}
export GRAFANA_NAMESPACE="${GRAFANA_NAMESPACE:-monitoring}"

if [[ "$INGRESS_NAMESPACE" =~ "istio" ]]; then
    ingress="istio"
    echo " -> Ingress controller type set to '$ingress'"
fi

echo " -> Creating Loki values from template"
if [[ "${LOKI_DISTRIBUTED,,}" == "true" ]]; then
    echo "   -> Using Loki distributed chart"
    cat loki/base/loki-values-distributed.yaml | envsubst > loki/base/loki-values.yaml
else
    echo "   -> Using Loki simple-scalable chart"
    cat loki/base/loki-values-ss.yaml | envsubst > loki/base/loki-values.yaml
fi

if [ -n "$LOKI_DOMAINNAME" ]; then
    cat loki/${ingress}/base/params.env.template | envsubst > loki/${ingress}/base/params.env
    if [ -f env/${envname}/certs/loki.crt ]; then
        echo " -> Copying Loki ingress certificates "
        cp env/${envname}/certs/loki* loki/${ingress}/base/
    fi
fi

echo " -> Creating s3 secrets.env for Mimir"
echo "$s3_secrets" | envsubst > mimir/base/secrets.env

if [ -n "$GRAFANA_DOMAINNAME" ]; then
    cat prometheus/${ingress}/base/params.env.template | envsubst > prometheus/${ingress}/base/params.env
    if [ -d env/${envname}/certs ]; then
        echo " -> Copying Grafana ingress certs"
        cp env/${envname}/certs/grafana.* prometheus/${ingress}/base/
    fi
fi

echo " -> Creating Helm Values and Configs from templates"
cat prometheus/base/prom-values.template.yaml | envsubst > prometheus/base/prom-values.yaml
cat prometheus/base/prom-addScrapeConfigs.template.yaml | envsubst > prometheus/base/prom-addScrapeConfigs.yaml
cat tempo/base/tempo-values.template.yaml | envsubst > tempo/base/tempo-values.yaml
cat alloy/base/config-template.alloy | envsubst > alloy/base/config.alloy

# license check
if [ -f env/${envname}/license.jwt ]; then
    echo " -> License file found, copying to overlays.."
    if [[ ! -d prometheus/overlays/${envname} ]]; then
        echo " -> Overlay directory for '${envname}' not found, creating.."
        mkdir -p prometheus/overlays/${envname}
        cp prometheus/overlays/example/kustomization.yaml prometheus/overlays/${envname}/
    fi
    if [[ ! -d loki/overlays/${envname} ]]; then
        mkdir -p loki/overlays/${envname}
        cp loki/overlays/example/kustomization.yaml loki/overlays/${envname}/
    fi
    cp env/${envname}/license.jwt prometheus/overlays/${envname}/ && \
    cp env/${envname}/license.jwt loki/overlays/${envname}/
    if [ $? -ne 0 ]; then
        echo "$PNAME Error copying license file" >&2
        exit 2
    fi
fi

echo " -> Needed S3 Buckets:"
# mimir s3 bucket names
buckets+=("$(yq e '.mimir.structuredConfig.alertmanager_storage.s3.bucket_name' mimir/base/mimir-structuredConfig.yaml | envsubst)")
buckets+=("$(yq e '.mimir.structuredConfig.blocks_storage.s3.bucket_name' mimir/base/mimir-structuredConfig.yaml | envsubst)")
buckets+=("$(yq e '.mimir.structuredConfig.ruler_storage.s3.bucket_name' mimir/base/mimir-structuredConfig.yaml | envsubst)")
# loki s3 bucket names
buckets+=("$(yq e '.loki.storage.bucketNames.chunks' loki/base/loki-values.yaml)")
buckets+=("$(yq e '.loki.storage.bucketNames.ruler' loki/base/loki-values.yaml)")
buckets+=("$(yq e '.loki.storage.bucketNames.admin' loki/base/loki-values.yaml)")
# tempo s3 bucket
buckets+=("$(yq -e '.storage.trace.s3.bucket' tempo/base/tempo-values.yaml)")

if [ -z "$s3cmd" ]; then
    echo " -> No S3 CLI detected, not creating buckets"
    echo "S3 Buckets needed:"
    for b in ${ary[@]}; do
        echo "$b"
    done
else
    create_s3_buckets "${buckets[@]}"
fi

echo " -> $PNAME Finished."

exit 0
