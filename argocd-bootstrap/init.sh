#!/usr/bin/env bash

ARGO_CD_VERSION=v1.8.5

BASE64_GITHUB_DEPLOY_KEY=$(cat ~/.ssh/id_rsa | base64 --wrap=0)
if [ -z "${BASE64_GITHUB_DEPLOY_KEY}" ]; then
  echo "BASE64_GITHUB_DEPLOY_KEY is empty"
  echo "You can generate the key issueing echo <key> | base64 --wrap=0"
  exit 1
fi

cat > main-app.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: main-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/puchz/cardano-node.git
    targetRevision: HEAD
    path: applications/main
    helm:
      valueFiles:
        - values-testnet.yaml

  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
EOF

cat > values-base.yaml << EOF
server:
  config:
    repositories: |
      - url: https://github.com/puchz/cardano-node.git
      - url: https://bitnami-labs.github.io/sealed-secrets
      - url: https://prometheus-community.github.io/helm-charts
        name: prometheus-community
        type: helm
global:
  image:
    repository: argoproj/argocd
    tag: ${ARGO_CD_VERSION}
EOF

echo "Adding argo-helm repo to helm"
helm repo add argo https://argoproj.github.io/argo-helm

echo "Creating argocd Namespace"
kubectl create ns argocd

echo "Creating github deploy key Secret"
echo "apiVersion: v1
kind: Secret
metadata:
  name: github-deploy-key
  namespace: argocd
data:
  sshPrivateKey: ${BASE64_GITHUB_DEPLOY_KEY}
type: Opaque" | kubectl apply -f -

helm upgrade -i argocd argo/argo-cd --version 2.10.0 -n argocd -f values-base.yaml

# Install ArgoCD main-app
kubectl apply -f main-app.yaml
rm main-app.yaml values-base.yaml
