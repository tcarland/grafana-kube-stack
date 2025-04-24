#!/usr/bin/env bash
#
#
PNAME=${0##*\/}
VERSION="v25.04.25"

binpath=$(dirname "$0")
project=$(dirname "$(realpath "$binpath")")

envname="$1"

export S3_BUCKET_NAME=${S3_BUCKET_NAME:-"mimir/data"}
export S3_SKIP_VERIFY=${MINIO_TLS_INSECURE:-"true"}

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

# strip protocol from endpoint
if [[ "$S3_ENDPOINT" =~ "http" ]]; then
    export S3_ENDPOINT=${S3_ENDPOINT#*//}
fi

( echo "$s3_secrets" | envsubst > mimir/base/secrets.env )

if [[ "$INGRESS_NAMESPACE" =~ "istio" ]]; then
    ingress="istio"
else
    ingress="nginx"
fi

cat prometheus/$ingress/base/params.env.template | envsubst > prometheus/$ingress/base/params.env
if [ -d env/${envname}/certs ]; then
    cp env/${envname}/certs/* prometheus/$ingress/base/
fi


exit 0
