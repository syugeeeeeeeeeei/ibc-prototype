#!/bin/bash
set -euo pipefail

echo "--> 📜 Tailing logs for gaia and relayer pods..."
echo "--> (Press Ctrl+C to exit)"

# app=gaia または app=relayer のラベルを持つ全てのPodのログをストリーミングします
# --tail=-1 で最後のログから全て表示し、-fで追跡します
kubectl logs -l 'app in (gaia, relayer)' -f --tail=-1 --all-containers=true