#!/usr/bin/env bash

verify() {
    docker build -t $(__imageName):DEV-SNAPSHOT .
}

deliver() {
    [[ $# -ne 1 ]] && { >&2 echo "Usage: $0 $FUNCNAME VERSION"; return 1; }
    local version=$1
    docker build -t $(__imageName):${version} .
    docker push $(__imageName):${version}
}

__imageName() {
    echo "docker.io/thxmasj/pipeline-branch"
}

usage() {
    echo "usage: $(basename $0) <command> [<args>]"
    echo
    echo "Available commands:"
    echo "   verify"
    echo "       Verify the build by creating an image with the tag 'DEV-SNAPSHOT'."
    echo "   deliver VERSION"
    echo "       Build the Docker image and push it to the registry. Use VERSION as the tag name."
}

case $1 in *)
        function=$1
        shift
        if [ "function" = "$(type -t ${function})" ]
        then
            ${function} "$@"
        else
            usage
        fi
        ;;
esac
