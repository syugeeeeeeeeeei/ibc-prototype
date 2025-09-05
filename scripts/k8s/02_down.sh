#!/bin/bash
set -euo pipefail

echo "--> 🔥 Deleting all Kubernetes resources..."

# '-f' で指定したファイルが存在しない場合でもエラーにならないように '|| true' を追加
kubectl delete -f ./k8s/gaia-statefulset.yaml --ignore-not-found=true
kubectl delete -f ./k8s/relayer-deployment.yaml --ignore-not-found=true
kubectl delete secret gaia-mnemonics --ignore-not-found=true
kubectl delete configmap gaia-scripts-config --ignore-not-found=true
kubectl delete configmap relayer-scripts-config --ignore-not-found=true

echo -e "\n✅ Deletion complete."