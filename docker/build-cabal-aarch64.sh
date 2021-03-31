#!/usr/bin/env bash
set -x

DOCKERFILE="cabal-3.2.0.0-aarch64.dockerfile"

docker build -t cabal:3.2.0.0 \
  -f ${DOCKERFILE} .
