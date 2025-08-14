.PHONY: apply delete scale-up scale-down get-pods get-services clean help
.DEFAULT_GOAL := help

# Kubernetesクラスタにマニフェストを適用し、サービスをデプロイ
apply:
	@echo "🚀 Applying Kubernetes manifests..."
	@kubectl apply -f k8s/
	@echo "✅ Deployment successful. You can now run 'make get-pods' to check the status."

# デプロイ済みのKubernetesリソースを全て削除
delete:
	@echo "🔥 Deleting Kubernetes resources..."
	@kubectl delete -f k8s/
	@echo "✅ All resources deleted."

# Gaiaノードを3つにスケールアップ
scale-up:
	@echo "⬆️ Scaling up Gaia nodes to 3 replicas..."
	@kubectl scale statefulset gaia-node --replicas=3
	@echo "✅ Gaia nodes scaled up. Run 'make get-pods' to confirm."

# Gaiaノードを2つにスケールダウン
scale-down:
	@echo "⬇️ Scaling down Gaia nodes to 2 replicas..."
	@kubectl scale statefulset gaia-node --replicas=2
	@echo "✅ Gaia nodes scaled down. Run 'make get-pods' to confirm."

# 全てのPodの状態を表示
get-pods:
	@echo "📜 Getting pod statuses..."
	@kubectl get pods

# 全てのServiceの状態を表示
get-services:
	@echo "📜 Getting service statuses..."
	@kubectl get services

# Gaiaノードのログを追跡表示
logs:
	@echo "📜 Tailing logs for all gaia-node pods..."
	@kubectl logs -f -l app=gaia-node

# 生成された.envファイルを削除
clean:
	@echo "🧹 Cleaning up generated files..."
	@rm -f .env

# ヘルプメッセージを表示
help:
	@echo "Usage:"
	@echo "  make apply       - (Run First) Applies all Kubernetes manifests to the cluster."
	@echo "  make delete      - Deletes all Kubernetes resources defined in k8s/."
	@echo "  make scale-up    - Scales the gaia-node StatefulSet to 3 replicas."
	@echo "  make scale-down  - Scales the gaia-node StatefulSet to 2 replicas."
	@echo "  make get-pods    - Shows the status of all pods."
	@echo "  make get-services- Shows the status of all services."
	@echo "  make logs        - Follows the container logs for all gaia-node pods."
	@echo "  make clean       - Removes generated files."