#!/usr/bin/env bash

set -x

export NODE_BUILD_NUM=$(curl https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/index.html | grep -e "build" | sed 's/.*build\/\([0-9]*\)\/download.*/\1/g')

if [ -z "${NODE_BUILD_NUM}" ]; then
  NODE_BUILD_NUM=5821110
fi

OS_ARCH=$(uname -m)

docker build -t cardano-node:1.25.1 \
  --build-arg GHC_VERSION=8.10.2 \
  --build-arg OS_ARCH="${OS_ARCH}" \
  --build-arg CARDANO_VERSION=1.25.1 \
  --build-arg OS_VERSION=linux \
  --build-arg NODE_BUILD_NUM=${NODE_BUILD_NUM} \
  -f 1.25.1.dockerfile .
