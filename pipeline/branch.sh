#!/usr/bin/env bash

image="docker.io/thxmasj/pipeline-branch"
docker pull ${image}
cwd=$(pwd -P)
docker run --rm -v ${cwd#/cygdrive}:/work ${image} ${@}
