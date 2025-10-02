#!/bin/bash
#
action="$1"
cmd=
buckets=(
    "mimir-blocks"
    "mimir-ruler"
    "mimir-alertmanager"
    "tempo-traces")

# prefer minio client
if which mc >/dev/null 2>&1; then
    if [ -z "${MINIO_ALIAS}" ]; then
        echo "> MINIO_ALIAS not set, must set to use 'mc'"
    else        
        echo "> Found Minio Client first, using 'mc mb ${MINIO_ALIAS}/'"
        cmd="mc mb ${MINIO_ALIAS}/"
    fi
fi

# alternatively use aws cli
if [ -z "$cmd" ]; then
    if which aws >/dev/null 2>&1; then
        echo "> Found the AWS CLI, using 'aws s3 mb s3://'"
        cmd="aws s3 mb s3://"
    else
        echo "$0 Error, no s3 client found (ie. mc or aws)"
        exit 1
    fi
fi

case "$action" in
'create'|'start'|'init')
    for b in ${buckets[@]}; do
        echo "${cmd}${b}"
        ( ${cmd}${b} )
    done
    ;;
'list'|'show')
    echo "Showing buckets to be created:"
    for b in ${buckets[@]}; do
        echo "${cmd}${b}"
    done
    ;;
*)
    echo ""
    echo "$0 <action>"
    echo "  where action = help|create|show"
    exit 0
    ;;
esac
exit $?
