#!/usr/bin/env bash

set -x

VERSION=0.1

GIT_COMMIT_SHA=$(git describe --always)

#TAG="${VERSION}-${GIT_COMMIT_SHA}"
TAG="${VERSION}"

docker build -t cn-utils:"${TAG}" .
