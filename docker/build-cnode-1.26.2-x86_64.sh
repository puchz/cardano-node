#!/usr/bin/env bash

set -x

export NODE_BUILD_NUM=$(curl https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/index.html | grep -e "build" | sed 's/.*build\/\([0-9]*\)\/download.*/\1/g')

if [ -z "${NODE_BUILD_NUM}" ]; then
  NODE_BUILD_NUM=5821110
fi

OS_ARCH=$(uname -m)

docker build -t cardano-node:1.26.2 \
  --build-arg NODE_BUILD_NUM=${NODE_BUILD_NUM} \
  -f 1.26.2-x86_64.dockerfile .
