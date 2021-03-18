#!/bin/bash
# --dry-run --debug
# helm upgrade --install cardano-node -f values-testnet.yaml .
helm install -f values-testnet.yaml cardano-node .
