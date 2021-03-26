#!/bin/bash
# --dry-run --debug
# helm install -f values-testnet.yaml cardano-node .
helm upgrade --install cardano-node -f values-testnet.yaml -n cardano-testnet .
