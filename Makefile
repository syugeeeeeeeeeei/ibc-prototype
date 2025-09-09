# .PHONY: 偽のターゲットを定義
.PHONY: help build-all build-datachain build-metachain deploy delete logs logs-chain logs-relayer status

# --- 変数定義 ---
APP_NAME ?= ibc-app
RELEASE_NAME ?= ibc-app
CHART_PATH ?= ./k8s/helm/$(APP_NAME)

# デフォルトのゴール
.DEFAULT_GOAL := help

# =============================================================================
# Main Commands
# =============================================================================

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
# Help
# =============================================================================

## help: このヘルプメッセージを表示します
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'