#!/bin/bash
set -euo pipefail

# 引数からノード数を取得。指定がなければデフォルトで2を使用
NODES=${1:-2}

echo "--> 🔑 Generating and deploying Kubernetes Secret for ${NODES} mnemonics..."
# 注意: denoとmnemonic-generatorスクリプトが実行環境に必要です
deno run --allow-all ./mnemonic-generator/generate.ts "${NODES}" | kubectl apply -f -

echo "--> 🛠️  Creating ConfigMaps from scripts..."
kubectl create configmap gaia-scripts-config --from-file=scripts/init.sh --dry-run=client -o yaml | kubectl apply -f -
kubectl create configmap relayer-scripts-config --from-file=scripts/init-relayer.sh --dry-run=client -o yaml | kubectl apply -f -

echo "--> 🚀 Deploying Gaia StatefulSet for ${NODES} nodes..."
sed "s/REPLICAS_PLACEHOLDER/${NODES}/" ./k8s/gaia-statefulset.yaml | kubectl apply -f -

echo "--> 🚀 Deploying Relayer Deployment for ${NODES} chains..."
sed "s/NUM_CHAINS_PLACEHOLDER/${NODES}/" ./k8s/relayer-deployment.yaml | kubectl apply -f -

echo -e "\n✅ Initialization complete. You can now check the status with 'make logs'."