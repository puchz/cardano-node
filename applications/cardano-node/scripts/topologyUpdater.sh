#!/usr/bin/env bash

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


if [ -z "${CNODE_PORT_UNO}" ]; then
  echo "Missing required CNODE_PORT_UNO env var. Exiting..."
  exit 1
fi

# Set env variables
PROM_PORT=12798
TIMEOUT=180
CNODE_VALENCY=1

# same k for testnet and mainnet
BYRON_K=2160
BYRON_SLOT_LENGTH=20000
BYRON_EPOCH_LENGTH=$(( 10 * BYRON_K ))

# same for testnet and mainnet
SHELLEY_SLOT_LENGTH=1
SHELLEY_SLOTS_PER_KES_PERIOD=129600

if [ "${NETWORK}" = "mainnet" ]; then
  NWMAGIC="764824073"
  SHELLEY_TRANS_EPOCH=208
  BYRON_GENESIS_START_SEC=1506203091
  NETWORK_IDENTIFIER="--mainnet"
  PROM_HOST=cardano-node-relay-int.cardano-mainnet.svc.cluster.local
else
  NWMAGIC="1097911063"
  SHELLEY_TRANS_EPOCH=74
  BYRON_GENESIS_START_SEC=1563999616
  NETWORK_IDENTIFIER="--testnet-magic ${NWMAGIC}"
  PROM_HOST=cardano-node-relay-int.cardano-testnet.svc.cluster.local
fi

# Description : Get calculated slot number tip
getSlotTipRef() {
  current_time_sec=$(printf '%(%s)T\n' -1)
  [[ ${SHELLEY_TRANS_EPOCH} -eq -1 ]] && echo 0 && return
  byron_slots=$(( SHELLEY_TRANS_EPOCH * BYRON_EPOCH_LENGTH ))
  byron_end_time=$(( BYRON_GENESIS_START_SEC + ((SHELLEY_TRANS_EPOCH * BYRON_EPOCH_LENGTH * BYRON_SLOT_LENGTH) / 1000) ))
  if [[ ${current_time_sec} -lt ${byron_end_time} ]]; then # In Byron phase
    echo $(( ((current_time_sec - BYRON_GENESIS_START_SEC)*1000) / BYRON_SLOT_LENGTH ))
  else # In Shelley phase
    echo $(( byron_slots + (( current_time_sec - byron_end_time ) / SHELLEY_SLOT_LENGTH ) ))
  fi
}

# Command     : getCurrentKESperiod
# Description : Offline calculation of current KES period based on reference tip
getCurrentKESperiod() {
  tip_ref=$(getSlotTipRef)
  echo $(( tip_ref / SLOTS_PER_KES_PERIOD ))
}

# Description : Calculate expected interval between blocks
slotInterval() {
  # testnet & mainnet  0 < 0.5 => 0.5
  d=0.5
  ACTIVE_SLOTS_COEFF=0.05
  echo "(${SHELLEY_SLOT_LENGTH} / ${ACTIVE_SLOTS_COEFF} / ${d}) + 0.5" | bc -l | awk '{printf "%.0f\n", $1}'
}

printf "Date ---> %s\n" "$(date)"

# Get metrics
node_metrics=$(curl -s -m ${TIMEOUT} "http://${PROM_HOST}:${PROM_PORT}/metrics" 2>/dev/null)
[[ ${node_metrics} =~ cardano_node_metrics_slotNum_int[[:space:]]([^[:space:]]*) ]] && slotnum=${BASH_REMATCH[1]}
[[ ${node_metrics} =~ cardano_node_metrics_blockNum_int[[:space:]]([^[:space:]]*) ]] && blocknum=${BASH_REMATCH[1]}

if [ -z "${blocknum}" ]; then
  echo "Missing block number (cardano_node_metrics_blockNum_int). Exiting..."
  exit 1
fi

if [[ ${slotnum} -eq 0 ]]; then
  syncLog="Status     : starting..."
elif [[ ${SHELLEY_TRANS_EPOCH} -eq -1 ]]; then
  syncLog="Status     : syncing..."
else
  tip_ref=$(getSlotTipRef)
  tip_diff=$(( tip_ref - slotnum ))
  if [[ ${tip_diff} -le $(slotInterval) ]]; then
    syncLog="Tip (diff) : ${tip_diff} :)"
  elif [[ ${tip_diff} -le $(( $(slotInterval) * 4 )) ]]; then
    syncLog="Tip (diff) : ${tip_diff} :|"
  else
    sync_progress=$(echo "(${slotnum}/${tip_ref})*100" | bc -l)
    syncLog="Status     : syncing ($(printf "%2.1f" "${sync_progress}")%)"
  fi
  echo $(date) >> /tmp/synclog.txt
  echo ${syncLog} >> /tmp/synclog.txt
fi

set -x

curl "${BASE_URL}/?port=${CNODE_PORT_UNO}&blockNo=${blocknum}&hostname=${CNODE_HOSTNAME}&valency=${CNODE_VALENCY}&magic=${NWMAGIC}"

if [ -n "${CNODE_PORT_DOS}" ]; then
  curl "${BASE_URL}/?port=${CNODE_PORT_DOS}&blockNo=${blocknum}&hostname=${CNODE_HOSTNAME}&valency=${CNODE_VALENCY}&magic=${NWMAGIC}"
fi

set +x

curl -o "${CNODE_TOPOLOGY}".tmp "${BASE_URL}/fetch/?max=${MAX_PEERS}&magic=${NWMAGIC}"

RELAY_UNO="/tmp/${NETWORK}-topology-relay-uno.json"
CUSTOM_PEERS_UNO="cardano-node-relay-dos.cardano-testnet.svc.cluster.local:3002:1|cardano-node-pool.cardano-mainnet.svc.cluster.local:3000:1|relays-new.cardano-mainnet.iohk.io:3001:2"
if [ -n "${CUSTOM_PEERS_UNO}" ]; then
  topo="$(cat "${CNODE_TOPOLOGY}".tmp)"
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

if [ -n "${CNODE_PORT_DOS}" ]; then
  RELAY_DOS="/tmp/${NETWORK}-topology-relay-dos.json"
  CUSTOM_PEERS_DOS="cardano-node-relay-uno.cardano-testnet.svc.cluster.local:3001:1|cardano-node-pool.cardano-mainnet.svc.cluster.local:3000:1|relays-new.cardano-mainnet.iohk.io:3001:2"
  if [ -n "${CUSTOM_PEERS_DOS}" ]; then
    topo="$(cat "${CNODE_TOPOLOGY}".tmp)"
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
fi
