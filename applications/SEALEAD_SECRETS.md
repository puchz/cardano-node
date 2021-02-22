# SEALED SECRETS
#### Una vez generado el cardano-${NETWORK}-certs.yaml , lo ejecutamos con `kubectl apply -f ...`
#### TODO --> KUBESEAL_CERT_PATH=sealed-secret.crt;
NETWORK=testnet;
NAMESPACE=cardano-testnet;
kubectl create secret generic ${NAMESPACE}-secrets --dry-run=client -o yaml -n ${NAMESPACE} --from-file=kes.skey --from-file=vrf.skey --from-file=node.cert | kubeseal --controller-name=sealed-secrets -o yaml > cardano-${NETWORK}-certs.yaml
