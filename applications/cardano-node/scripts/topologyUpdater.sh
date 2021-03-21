#!/usr/bin/env bash

set -x

# NODE_BUILD_NUM
# echo export NODE_BUILD_NUM=$(curl https://hydra.iohk.io/job/Cardano/iohk-nix/cardano-deployment/latest-finished/download/1/index.html | grep -e "build" | sed 's/.*build\/\([0-9]*\)\/download.*/\1/g')
# NODE_CONFIG
# echo export NODE_CONFIG=mainnet

if [ -z "${NETWORK}" ]; then
  echo "Missing required NETWORK env var. Exiting..."
  exit 1
fi

if [ -z "${BASE_URL}" ]; then
  echo "Missing required BASE_URL env var. Exiting..."
  exit 1
fi

if [ -z "${CNODE_HOSTNAME}" ]; then
  echo "Missing required CNODE_HOSTNAME env var. Exiting..."
  exit 1
fi

if [ -z "${CNODE_PORT}" ]; then
  echo "Missing required CNODE_PORT env var. Exiting..."
  exit 1
fi

CNODE_VALENCY=1

if [ "${NETWORK}" = "mainnet" ]; then
  NWMAGIC="764824073"
  blockNo=$(curl -s cardano-node-relay-int.cardano-mainnet.svc.cluster.local:12798/metrics | grep cardano_node_metrics_blockNum_int  | awk '{print $NF}')
else
  NWMAGIC="1097911063"
  blockNo=$(curl -s cardano-node-relay-int.cardano-testnet.svc.cluster.local:12798/metrics | grep cardano_node_metrics_blockNum_int  | awk '{print $NF}')
fi

NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

if [ ! -z "${CNODE_HOSTNAME}" ]
then
  HOSTNAME_ARG="&hostname=${CNODE_HOSTNAME}"
fi

CURL_COMMAND="curl ${BASE_URL}/?port=${CNODE_PORT}&blockNo=${blockNo}${HOSTNAME_ARG}&valency=${CNODE_VALENCY}&magic=${NWMAGIC}"

echo "=> (${CURL_COMMAND})"

date

curl "${BASE_URL}/?port=${CNODE_PORT}&blockNo=${blockNo}${HOSTNAME_ARG}&valency=${CNODE_VALENCY}&magic=${NWMAGIC}"
curl -o "${CNODE_TOPOLOGY}".tmp "${BASE_URL}/fetch/?max=${MAX_PEERS}&magic=${NWMAGIC}"
