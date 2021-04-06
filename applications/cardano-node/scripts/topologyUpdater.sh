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

if [ -z "${BLOCKNO}" ]; then
  echo "Missing block number (cardano_node_metrics_blockNum_int). Exiting..."
  exit 1
fi

if [ ! -z "${CNODE_HOSTNAME}" ]
then
  HOSTNAME_ARG="&hostname=${CNODE_HOSTNAME}"
else
  HOSTNAME_ARG=''
fi

curl "${BASE_URL}/?port=${CNODE_PORT}&blockNo=${BLOCKNO}${HOSTNAME_ARG}&valency=${CNODE_VALENCY}&magic=${NWMAGIC}"
curl -o "${CNODE_TOPOLOGY}".tmp "${BASE_URL}/fetch/?max=${MAX_PEERS}&magic=${NWMAGIC}"

TOPOLOGY=/tmp/topology.json
RELAY_UNO="${NETWORK}-topology-relay-uno.json"
RELAY_DOS="${NETWORK}-topology-relay-dos.json"
CUSTOM_PEERS_UNO="cardano-node-relay-dos.cardano-testnet.svc.cluster.local:3002:1|cardano-node-pool.cardano-mainnet.svc.cluster.local:3000:1|relays-new.cardano-mainnet.iohk.io:3001:2"
CUSTOM_PEERS_DOS="cardano-node-relay-uno.cardano-testnet.svc.cluster.local:3001:1|cardano-node-pool.cardano-mainnet.svc.cluster.local:3000:1|relays-new.cardano-mainnet.iohk.io:3001:2"

if [ -n "${CUSTOM_PEERS_UNO}" ]; then
  topo="$(cat "${TOPOLOGY}".tmp)"
  IFS='|' read -ra cpeers <<< ${CUSTOM_PEERS_UNO}
  for p in "${cpeers[@]}"; do
    colons=$(echo "${p}" | tr -d -c ':' | awk '{print length}')
    case $colons in
      1) addr="$(cut -d: -f1 <<< "${p}")"
         port=$(cut -d: -f2 <<< "${p}")
         valency=1;;
      2) addr="$(cut -d: -f1 <<< "${p}")"
         port=$(cut -d: -f2 <<< "${p}")
         valency=$(cut -d: -f3 <<< "${p}");;
      *) echo "ERROR: Invalid Custom Peer definition '${p}'. Please double check CUSTOM_PEERS definition"
         exit 1;;
    esac
    topo=$(jq '.Producers += [{"addr": $addr, "port": $port|tonumber, "valency": $valency|tonumber}]' --arg addr "${addr}" --arg port ${port} --arg valency ${valency} <<< "${topo}")
  done
  echo "${topo}" | jq -r . >/dev/null 2>&1 && echo "${topo}" > "${RELAY_UNO}".tmp
fi

if [ -n "${CUSTOM_PEERS_DOS}" ]; then
  topo="$(cat "${TOPOLOGY}".tmp)"
  IFS='|' read -ra cpeers <<< ${CUSTOM_PEERS_DOS}
  for p in "${cpeers[@]}"; do
    colons=$(echo "${p}" | tr -d -c ':' | awk '{print length}')
    case $colons in
      1) addr="$(cut -d: -f1 <<< "${p}")"
         port=$(cut -d: -f2 <<< "${p}")
         valency=1;;
      2) addr="$(cut -d: -f1 <<< "${p}")"
         port=$(cut -d: -f2 <<< "${p}")
         valency=$(cut -d: -f3 <<< "${p}");;
      *) echo "ERROR: Invalid Custom Peer definition '${p}'. Please double check CUSTOM_PEERS definition"
         exit 1;;
    esac
    topo=$(jq '.Producers += [{"addr": $addr, "port": $port|tonumber, "valency": $valency|tonumber}]' --arg addr "${addr}" --arg port ${port} --arg valency ${valency} <<< "${topo}")
  done
  echo "${topo}" | jq -r . >/dev/null 2>&1 && echo "${topo}" > "${RELAY_DOS}".tmp
fi
