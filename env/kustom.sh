#!/usr/bin/env bash
#
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    echo "$0  is being executed directly."
    echo " It is intended to be sourced by the shell"
    echo " eg. \$ source kustom.sh"
    exit 1
fi


# kustomize wrapper for auto-detecting helm charts
# this requires 'yq' 
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
