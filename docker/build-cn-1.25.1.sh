#!/usr/bin/env bash

set -x

OS_ARCH=$(uname -m)

docker build -t cardano-node:1.25.1 \
  --build-arg GHC_VERSION=8.10.2 \
  --build-arg OS_ARCH="${OS_ARCH}" \
  --build-arg CARDANO_VERSION=1.25.1 \
  --build-arg OS_VERSION=linux \
  -f 1.25.1.dockerfile .
