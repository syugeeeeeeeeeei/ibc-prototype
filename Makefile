# .PHONY: 偽のターゲットを定義
.PHONY: help build-all build-datachain build-metachain build-relayer deploy delete delete-force logs logs-chain logs-relayer status debug-info portainer-up portainer-down portainer-info dashboard-up dashboard-down dashboard-setup dashboard-token tx-test

# --- 変数定義 ---
APP_NAME ?= ibc-app
RELEASE_NAME ?= ibc-app
CHART_PATH ?= ./k8s/helm/$(APP_NAME)
HEADLESS_SERVICE_NAME = $(RELEASE_NAME)-chain-headless

# デフォルトのゴール
.DEFAULT_GOAL := help

# =============================================================================
# Main Commands
# =============================================================================

## build-all: 全てのチェーンのDockerイメージをビルドします
build-all: build-datachain build-metachain build-relayer

## build-datachain: datachainのDockerイメージをビルドします
build-datachain:
	@echo "🏗️  Building datachain image from definition..."
	@docker build -t datachain-image:latest -f ./build/datachain/Dockerfile .
## build-metachain: metachainのDockerイメージをビルドします
build-metachain:
	@echo "🏗️  Building metachain image from definition..."
	@docker build -t metachain-image:latest -f ./build/metachain/Dockerfile .
## build-relayer: relayerのDockerイメージをビルドします
build-relayer:
	@echo "🏗️  Building relayer image from definition..."
	@docker build -t relayer-image:latest -f ./build/relayer/Dockerfile .
## deploy: HelmチャートをKubernetesクラスタにデプロイします
deploy:
	@echo "🚀  Deploying Helm chart to cluster..."
	@helm upgrade --install $(RELEASE_NAME) $(CHART_PATH) --debug

## delete: デプロイのみを削除します (ボリュームは残ります)
delete:
	@echo "🔥  Deleting Helm release (volumes will be kept)..."
	@helm uninstall $(RELEASE_NAME) --ignore-not-found=true

## delete-force: デプロイとボリューム(PVC)を完全に削除します
delete-force:
	@echo "🔥  Deleting Helm release from cluster..."
	@helm uninstall $(RELEASE_NAME) --ignore-not-found=true
	@echo "🧹  Deleting Persistent Volume Claims (PVCs)..."
	@kubectl delete pvc -l "app.kubernetes.io/name=$(APP_NAME)" --ignore-not-found=true

# =============================================================================
# Chain Scaffolding Commands
# =============================================================================

## scaffold-all: 全てのチェーンのソースコードをローカルに生成します
scaffold-all: scaffold-datachain scaffold-metachain

## scaffold-datachain: datachainのソースコードを ./chain/datachain に生成します
scaffold-datachain:
	@if [ -d "chain/datachain" ]; then \
		echo "ℹ️  'chain/datachain' directory already exists. Skipping scaffold."; \
	else \
		echo "🏗️  Scaffolding datachain source code..."; \
		ignite scaffold chain datachain --skip-git --default-denom uatom --skip-proto --path ./chain/datachain; \
		cd chain/datachain && \
		ignite scaffold module datastore --ibc --dep bank --yes && \
		ignite scaffold packet chunk index:string data:bytes --module datastore --yes && \
		ignite scaffold map stored-chunk data:bytes --module datastore --signer creator --yes && \
		sed -i 's/"datastore-1"/"ibc-proto-1"/g' x/datastore/types/keys.go && \
		cd ../..; \
		echo "✅  datachain source code scaffolded in 'chain/datachain'"; \
	fi

## scaffold-metachain: metachainのソースコードを ./chain/metachain に生成します
scaffold-metachain:
	@if [ -d "chain/metachain" ]; then \
		echo "ℹ️  'chain/metachain' directory already exists. Skipping scaffold."; \
	else \
		echo "🏗️  Scaffolding metachain source code..."; \
		ignite scaffold chain metachain --skip-git --default-denom uatom --skip-proto --path ./chain/metachain; \
		cd chain/metachain && \
		ignite scaffold module metastore --ibc --dep bank --yes && \
		ignite scaffold packet metadata url:string addresses:array.string --module metastore --yes && \
		ignite scaffold map stored-meta url:string --module metastore --signer creator --yes && \
		sed -i 's/"metastore-1"/"ibc-proto-1"/g' x/metastore/types/keys.go && \
		cd ../..; \
		echo "✅  metachain source code scaffolded in 'chain/metachain'"; \
	fi

# =============================================================================
# Utility and Debugging Commands
# =============================================================================

## status: デプロイされたPodのステータスを表示します
status:
	@echo "📊  Checking status of deployed pods..."
	@kubectl get pods -l "app.kubernetes.io/name=$(APP_NAME)"

## logs: 全てのPodのログを表示します
logs: logs-chain logs-relayer

## logs-chain: チェーンノードのPodのログを追跡表示します
logs-chain:
	@echo "📜  Tailing logs for chain nodes..."
	@kubectl logs -l "app.kubernetes.io/name=$(APP_NAME),app.kubernetes.io/component=chain" -f --tail=100

## logs-relayer: リレイヤーのPodのログを追跡表示します
logs-relayer:
	@echo "📜  Tailing logs for relayer..."
	@kubectl logs \
-l "app.kubernetes.io/name=$(APP_NAME),app.kubernetes.io/component=relayer" -f --tail=100

## debug-info: 問題発生時に全ての関連情報を一括で表示します
debug-info:
	@echo "ախ  Gathering all debug information..."
	@echo "\n--- 1. Pod Status & IP Addresses ---"
	@kubectl get pods -o wide
	@echo "\n--- 2. Headless Service Network Endpoints ---"
	@kubectl describe service $(HEADLESS_SERVICE_NAME)
	@echo "\n--- 3. Relayer Pod Logs ---"
	@RELAYER_POD=$$(kubectl get pods -l "app.kubernetes.io/instance=$(RELEASE_NAME),app.kubernetes.io/component=relayer" -o jsonpath='{.items[0].metadata.name}'); \
	if [ -n "$$RELAYER_POD" ]; then \
		kubectl logs $$RELAYER_POD; \
		echo "\n--- 4. DNS Resolution Test from Relayer Pod ---"; \
		CHAIN_PODS=$$(\
			kubectl get pods -l "app.kubernetes.io/name=$(APP_NAME),app.kubernetes.io/component=chain" -o jsonpath='{.items[*].metadata.name}' \
		); \
		for POD_NAME in $$CHAIN_PODS; do \
			echo "\n--> Checking DNS for $$POD_NAME..."; \
			kubectl exec -i $$RELAYER_POD -- nslookup $$POD_NAME.$(HEADLESS_SERVICE_NAME) || true; \
		done; \
	else \
		echo "Relayer pod not found."; \
	fi
	@echo "\n--- 5. Chain Pod Logs (Last 100 lines) ---"
	@CHAIN_PODS=$$(kubectl get pods -l "app.kubernetes.io/name=$(APP_NAME),app.kubernetes.io/component=chain" -o jsonpath='{.items[*].metadata.name}'); \
	if [ -n "$$CHAIN_PODS" ]; then \
		for POD_NAME in $$CHAIN_PODS; do \
			echo "\n--> Logs for $$POD_NAME:"; \
			kubectl logs $$POD_NAME --tail=100; \
		done; \
	else \
		echo "Chain pods not found."; \
	fi
	@echo "\n--- ✅ Debug information gathering complete ---"


# =============================================================================
# K8s Management UI (Portainer & Dashboard)
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
	@kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard --dry-run=client -o yaml | \
	kubectl apply -f -
	@kubectl create clusterrolebinding dashboard-admin-binding --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-admin --dry-run=client -o yaml | \
	kubectl apply -f -
	@echo "✅ Setup complete. Run 'make dashboard-token' to retrieve the access token."
## dashboard-token: Dashboardへのアクセストークンを取得します
dashboard-token:
	@echo "🔑  Retrieving access token for Kubernetes Dashboard..."
	@TOKEN=$$(kubectl create token dashboard-admin -n kubernetes-dashboard); \
	echo "---"; \
	echo "Access Token:"; \
	echo "$$TOKEN"; \
	echo "---"

tx-test:
	@echo "🔄  Running test transaction between chains..."
	@./scripts/test/tx-test.sh
	
# =============================================================================
# Help
# =============================================================================

## help: このヘルプメッセージを表示します
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
	sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'