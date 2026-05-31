#!/usr/bin/env bash
#
# Timothy C. Arland <tcarland at gmail dot com>
PNAME=${0##*\/}
VERSION="v26.05.31"

binpath=$(dirname "$0")
project=$(dirname "$(realpath "$binpath")")
envname="$1"
ingress="istio"
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


#  MAIN
# ---------------------------------------
# Validation 
echo "$PNAME $VERSION"

if ! which helm >/dev/null 2>&1; then
    echo "$PNAME Error, required binary 'helm' not found in PATH." >&2
    exit 2
fi

if ! which yq >/dev/null 2>&1; then
    echo "$PNAME Error, required binary 'yq' not found in PATH." >&2
    exit 2
fi

if [ -z "$envname" ]; then
    echo "$PNAME Error, ENV name not provided" >&2
    echo "  The name should match the environment path under env/" >&2
    exit 1
fi

if [ ! -f "env/${envname}/${envname}.env" ]; then
    echo "$PNAME Error, ENV file env/${envname}/${envname}.env not found." >&2
    exit 1
fi

source env/${envname}/${envname}.env

if [ -z "$S3_ENDPOINT" ]; then
    echo "$PNAME Error, S3_ENDPOINT not defined." >&2
    exit 1
fi

if [[ -z "$S3_ACCESS_KEY" || -z "$S3_SECRET_KEY" ]]; then
    echo "$PNAME Error, S3 credentials not defined." >&2
    exit 1
fi

if [ -z "$GRAFANA_ENV" ]; then
    echo "$PNAME Error, GRAFANA_ENV not defined." >&2
    echo "  This name is used for overlay paths" >&2
    exit 1
fi

# strip protocol prefix from endpoint if defined
if [[ "$S3_ENDPOINT" =~ "http" ]]; then
    export S3_ENDPOINT=${S3_ENDPOINT#*//}
fi

# prefer minio client
if which mc >/dev/null 2>&1; then
    if [ -z "${MINIO_ALIAS}" ]; then
        echo " -> MINIO_ALIAS is not set, configure it to use 'mc'"
    else
        echo " -> Found Minio Client, using 'mc mb ${MINIO_ALIAS}/'..."
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
export GRAFANA_ADMIN_USER="${GRAFANA_ADMIN_USER:-admin}"
export GRAFANA_ADMIN_PASSWORD="${GRAFANA_ADMIN_PASSWORD:-admin}"

# Ingress config. INGRESS_NAMESPACE should 'istio-system' for istio or 'ingress-nginx' for nginx
if [[ "$INGRESS_NAMESPACE" =~ "istio" ]]; then
    ingress="istio"
    cat ingress/istio/istio-operator-template.yaml | envsubst > ingress/istio/istio-operator.yaml
else
    ingress="nginx"
    cat ingress/nginx/base/nginx-values-template.yaml | envsubst > ingress/nginx/base/nginx-values.yaml
fi
echo " -> Ingress controller type set to '$ingress' given INGRESS_NAMESPACE='$INGRESS_NAMESPACE'"

# Create namespace if not exists
if ! kubectl get namespace "$GRAFANA_NAMESPACE" >/dev/null 2>&1; then
    echo " -> Creating namespace '$GRAFANA_NAMESPACE'"
    kubectl create namespace "$GRAFANA_NAMESPACE" >/dev/null 2>&1
fi

# -----------------
# Loki
echo " -> Creating Loki values from template"
cat loki/base/loki-values.template.yaml | envsubst > loki/base/loki-values.yaml

# Loki Ingress
if [ -n "$LOKI_DOMAINNAME" ]; then
    cat loki/ingress/${ingress}/base/params.env.template | envsubst > loki/ingress/${ingress}/base/params.env
    if [ -f env/${envname}/certs/loki.crt ]; then
        echo "   -> Copying Loki ingress certificates "
        cp env/${envname}/certs/loki* loki/ingress/${ingress}/base/
    fi
fi


# -----------------
# Mimir
echo " -> Creating Mimir s3 secrets and values frome template"
echo "$s3_secrets" | envsubst > mimir/base/secrets.env
cat mimir/base/mimir-values.template.yaml | envsubst > mimir/base/mimir-values.yaml

# Mimir Ingress
if [ -n "$MIMIR_DOMAINNAME" ]; then
    cat mimir/ingress/${ingress}/base/params.env.template | envsubst > \
        mimir/ingress/${ingress}/base/params.env
    if [ -f env/${envname}/certs/mimir.crt ]; then
        echo "   -> Copying Mimir ingress certificates "
        cp env/${envname}/certs/mimir* mimir/ingress/${ingress}/base/
    fi
fi    


# -----------------
# Grafana / Prometheus
echo " -> Creating Grafana and Prometheus Values from templates"

cat grafana/base/grafana-values.template.yaml | envsubst > grafana/base/grafana-values.yaml
cat grafana/base/secrets.template.env | envsubst > grafana/base/secrets.env

cat prometheus/base/prom-values.template.yaml | envsubst > prometheus/base/prom-values.yaml
cat prometheus/base/prom-addScrapeConfigs.template.yaml | envsubst > prometheus/base/prom-addScrapeConfigs.yaml

# Grafana Ingress
if [ -n "$GRAFANA_DOMAINNAME" ]; then
    cat grafana/ingress/${ingress}/base/params.env.template | envsubst > \
        grafana/ingress/${ingress}/base/params.env
    if [ -d env/${envname}/certs ]; then
        echo "   -> Copying Grafana ingress certs"
        cp env/${envname}/certs/grafana.* grafana/ingress/${ingress}/base/
    fi
fi

# Prometheus Ingress
if [ -n "$PROMETHEUS_DOMAINNAME" ]; then
    cat prometheus/ingress/${ingress}/base/params.env.template | envsubst > \
        prometheus/ingress/${ingress}/base/params.env
        
    if [[ "$ingress" == "nginx" ]]; then  # nginx uses bcrypt pw via htpasswd
        ( echo "${AGENT_PASSWORD}" | \
          htpasswd -c -i prometheus/ingress/$ingress/base/auth "${AGENT_USERNAME}" )
    else  # create base64 auth str for the istio virtualservice
        export AGENTAUTHSTR=$(printf "%s" "${AGENT_USERNAME}:${AGENT_PASSWORD}" | base64 -w0)
        cat prometheus/ingress/${ingress}/base/prometheus-virtualservice-template.yaml | envsubst > \
            prometheus/ingress/${ingress}/base/prometheus-virtualservice.yaml
    fi
    if [ -d env/${envname}/certs ]; then
        echo "   -> Copying Prometheus ingress certs"
        cp env/${envname}/certs/prometheus.* prometheus/ingress/${ingress}/base/
    fi
fi


# -----------------
# Tempo
echo " -> Creating Tempo values from template"
cat tempo/base/tempo-values.template.yaml | envsubst > tempo/base/tempo-values.yaml

# Tempo Ingress
if [ -n "$TEMPO_DOMAINNAME" ]; then
    cat tempo/ingress/${ingress}/base/params.env.template | envsubst > tempo/ingress/${ingress}/base/params.env
    if [ -d env/${envname}/certs ]; then
        echo "   -> Copying Tempo ingress certs"
        cp env/${envname}/certs/tempo.* tempo/ingress/${ingress}/base/
    fi
fi


# -----------------
# Alloy
echo " -> Alloy configs from template "
cat alloy/base/config-template.alloy | envsubst > alloy/base/config.alloy


# -----------------
# license check
if [ -f env/${envname}/files/license.jwt ]; then
    echo " -> License file found, copying to overlays.."
    if [[ ! -f grafana/overlays/${envname}/kustomization.yaml ]]; then
        echo " -> Overlay directory for '${envname}' not found, creating.."
        mkdir -p grafana/overlays/${envname}
        cp grafana/overlays/example/kustomization.yaml grafana/overlays/${envname}/
    fi
    if [[ ! -f loki/overlays/${envname}/kustomization.yaml ]]; then
        mkdir -p loki/overlays/${envname}
        cp loki/overlays/example/kustomization.yaml loki/overlays/${envname}/
    fi

    cp env/${envname}/files/license.jwt grafana/overlays/${envname}/ && \
    cp env/${envname}/files/license.jwt loki/overlays/${envname}/

    if [ $? -ne 0 ]; then
        echo "$PNAME Error copying license file" >&2
        exit 2
    fi
fi


# -----------------
printf "\n -> Required S3 Buckets: \n"

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

for b in ${buckets[@]}; do
    echo "$b"
done
echo ""

if [[ -n "$s3cmd" && -z "$S3_SKIP_CREATE" ]]; then
    echo " -> create_s3_buckets()"
    create_s3_buckets "${buckets[@]}"
fi

echo "$PNAME finished."

exit 0
