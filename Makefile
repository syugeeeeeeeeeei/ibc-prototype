# .PHONY: 偽のターゲットを定義
.PHONY: help init init-datachain init-metachain build-all build-datachain build-metachain deploy delete logs logs-chain logs-relayer status portainer-up portainer-down portainer-info dashboard-up dashboard-down dashboard-setup dashboard-token

# --- 変数定義 ---
APP_NAME ?= ibc-app
RELEASE_NAME ?= ibc-app
CHART_PATH ?= ./k8s/helm/$(APP_NAME)

# デフォルトのゴール
.DEFAULT_GOAL := help

# =============================================================================
# Main Commands
# =============================================================================

## init: datachainとmetachainのソースコードを初期化します
init: init-datachain init-metachain

## init-datachain: datachainのソースコードを./chain/datachainに生成します
init-datachain:
	@echo "▶️  datachain生成スクリプトを実行します..."
	@chmod +x ./scripts/create-datachain.sh
	@./scripts/create-datachain.sh

## init-metachain: metachainのソースコードを./chain/metachainに生成します
init-metachain:
	@echo "▶️  metachain生成スクリプトを実行します..."
	@chmod +x ./scripts/create-metachain.sh
	@./scripts/create-metachain.sh

## build-all: 全てのチェーンのDockerイメージをビルドします
build-all: build-datachain build-metachain

## build-datachain: datachainのDockerイメージをビルドします
build-datachain:
	@echo "🏗️  Building datachain image from definition..."
	@docker build -t datachain-image:latest -f ./build/datachain/Dockerfile .

## build-metachain: metachainのDockerイメージをビルドします
build-metachain:
	@echo "🏗️  Building metachain image from definition..."
	@docker build -t metachain-image:latest -f ./build/metachain/Dockerfile .

## deploy: HelmチャートをKubernetesクラスタにデプロイします
deploy:
	@echo "🚀  Deploying Helm chart to cluster..."
	@helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) --wait

## delete: Kubernetesクラスタからデプロイを削除します
delete:
	@echo "🔥  Deleting Helm release from cluster..."
	@helm uninstall $(RELEASE_NAME)

# =============================================================================
# Utility Commands
# =============================================================================

## logs: 全てのPodのログを表示します
logs: logs-chain logs-relayer

## logs-chain: チェーンノードのPodのログを表示します
logs-chain:
	@echo "📜  Tailing logs for chain nodes..."
	@kubectl logs -l "app.kubernetes.io/name=$(APP_NAME),app.kubernetes.io/component=chain" -f --tail=100

## logs-relayer: リレイヤーのPodのログを表示します
logs-relayer:
	@echo "📜  Tailing logs for relayer..."
	@kubectl logs -l "app.kubernetes.io/name=$(APP_NAME),app.kubernetes.io/component=relayer" -f --tail=100

## status: デプロイされたPodのステータスを表示します
status:
	@echo "📊  Checking status of deployed pods..."
	@kubectl get pods -l "app.kubernetes.io/name=$(APP_NAME)"

# =============================================================================
# K8s Management UI (Portainer)
# =============================================================================

## portainer-up: PortainerをKubernetesクラスタにデプロイします
portainer-up:
	@echo "🌐  Deploying Portainer..."
	@kubectl create namespace portainer
	@kubectl apply -n portainer -f https://downloads.portainer.io/ce2-19/portainer.yaml
	@echo "✅  Portainer deployed. Use 'make portainer-info' to get access details."

## portainer-down: PortainerをKubernetesクラスタから削除します
portainer-down:
	@echo "🔥  Deleting Portainer..."
	@kubectl delete -n portainer -f https://downloads.portainer.io/ce2-19/portainer.yaml
	@kubectl delete namespace portainer --ignore-not-found=true

## portainer-info: Portainerへのアクセス情報を表示します
portainer-info:
	@echo "🔑  Access Portainer UI via NodePort:"
	@echo "1. Get the NodePort using the following command:"
	@echo "   kubectl get svc -n portainer"
	@echo "2. Access https://localhost:<NODE_PORT> in your browser (use the port mapped to 9443)."

# =============================================================================
# K8s Management UI (Kubernetes Dashboard)
# =============================================================================

## dashboard-up: Kubernetes Dashboardをデプロイします
dashboard-up:
	@echo "🌐 Deploying Kubernetes Dashboard..."
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
	@echo "✅ Kubernetes Dashboard deployed. Run 'make dashboard-setup' to configure access."

## dashboard-down: Kubernetes Dashboardを削除します
dashboard-down:
	@echo "🔥 Deleting Kubernetes Dashboard..."
	@kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
	@kubectl delete sa dashboard-admin -n kubernetes-dashboard --ignore-not-found=true
	@kubectl delete clusterrolebinding dashboard-admin-binding --ignore-not-found=true

## dashboard-setup: Dashboard用の管理者アカウントを作成します
dashboard-setup:
	@echo "🛠️  Creating dashboard-admin ServiceAccount and ClusterRoleBinding..."
	@kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create clusterrolebinding dashboard-admin-binding --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-admin --dry-run=client -o yaml | kubectl apply -f -
	@echo "✅ Setup complete. Run 'make dashboard-token' to retrieve the access token."

## dashboard-token: Dashboardへのアクセストークンを取得します
dashboard-token:
	@echo "🔑  Retrieving access token for Kubernetes Dashboard..."
	@TOKEN=$$(kubectl create token dashboard-admin -n kubernetes-dashboard); \
	echo "---"; \
	echo "Access Token:"; \
	echo "$$TOKEN"; \
	echo "---"

# =============================================================================
# Help
# =============================================================================

## help: このヘルプメッセージを表示します
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
