sh ./sealedsecret.sh
kubectl create configmap node-configuration-testnet --from-file=configmap -o yaml
kubectl create -f cn-statefulset-pool.yaml
kubectl create -f cn-statefulset-relay.yaml
kubectl create -f cn-statefulset-relay-2.yaml
kubectl create -f cn-svc.yaml
