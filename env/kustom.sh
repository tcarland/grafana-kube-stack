#!/usr/bin/env bash
#
# A kustomize wrapper for auto-detecting helm chart expansion
# dynamically adding '--enable-helm' to kustomize commands.
# This requires 'yq'  


if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "$0 is being executed directly. It should be sourced instead."
    echo " eg. \$ source kustom.sh"
    exit 1
fi


function kustom()
{
    local action=
    local target=
    local yml=
    local helm="false"
    local args=()

    args+=("$@")
    if [ ${#args[@]} -eq 2 ]; then
        action=${args[0]}
        target=${args[1]}
        args=("${args[@]:2}")
    fi

    if [ -r $target/base/kustomization.yaml ]; then
        yml=$target/base/kustomization.yaml
    elif [ -r $target/../../base/kustomization.yaml ]; then
        yml=$target/../../base/kustomization.yaml
    elif [ -r $target/kustomization.yaml ]; then
        yml=$target/kustomization.yaml
    fi

    if [[ $(yq e 'has("helmCharts")' $yml) == "true" ]]; then
        action="$action --enable-helm"
    fi

    ( \kustomize $action $target ${args[@]} )

    return $?
}

alias kustomize=kustom
