#!/usr/bin/env bash
set -x

OS_ARCH=$(uname -m)
DOCKERFILE="cabal-3.2.0.0-x86_64_2.dockerfile"

docker build -t cabal:3.2.0.0 \
  -f ${DOCKERFILE} . \
  --build-arg OS_ARCH="${OS_ARCH}"
