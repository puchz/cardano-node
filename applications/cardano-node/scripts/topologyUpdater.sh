#!/usr/bin/env bash

set -x

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
  BLOCKNO=$(curl -s cardano-node-relay-int.cardano-mainnet.svc.cluster.local:12798/metrics | grep cardano_node_metrics_blockNum_int  | awk '{print $NF}')
else
  NWMAGIC="1097911063"
  BLOCKNO=$(curl -s cardano-node-relay-int.cardano-testnet.svc.cluster.local:12798/metrics | grep cardano_node_metrics_blockNum_int  | awk '{print $NF}')
fi

printf "Date ---> %s\n" "$(date)"

curl -o "${CNODE_TOPOLOGY}".tmp "${BASE_URL}/fetch/?max=${MAX_PEERS}&magic=${NWMAGIC}"

if [ -z "${BLOCKNO}" ]; then
  echo "Missing block number (cardano_node_metrics_blockNum_int). Exiting..."
  exit 1
fi

if [ ! -z "${CNODE_HOSTNAME}" ]
then
  HOSTNAME_ARG="&hostname=${CNODE_HOSTNAME}"
fi

curl "${BASE_URL}/?port=${CNODE_PORT}&blockNo=${BLOCKNO}${HOSTNAME_ARG}&valency=${CNODE_VALENCY}&magic=${NWMAGIC}"
