# .PHONY は、同名のファイルが存在してもターゲットを実行するようにするための宣言です
.PHONY: init start down logs clean help dashboard-up dashboard-down dashboard-token dashboard-setup create-datachain start-datachain delete-datachain test-tx tx-create tx-update tx-delete tx-show tx-show-fail

.DEFAULT_GOAL := help

# ====================================================================================
# Kubernetes IBC Environment Management
# ====================================================================================

# K8sクラスタへのデプロイ
NODES ?= 2

init:
	@echo "🔑 Generating and deploying Kubernetes Secret for mnemonics..."
	@deno run --allow-all ./mnemonic-generator/generate.ts $(NODES) | kubectl apply -f -
	@echo "🛠️ 	Creating ConfigMaps from scripts..."
	@kubectl create configmap gaia-scripts-config --from-file=scripts/init.sh --dry-run=client -o yaml | kubectl apply -f -
	@kubectl create configmap relayer-scripts-config --from-file=scripts/init-relayer.sh --dry-run=client -o yaml | kubectl apply -f -
	@echo "🚀 Deploying Gaia StatefulSet and Relayer Deployment for $(NODES) nodes..."
	@sed "s/REPLICAS_PLACEHOLDER/$(NODES)/" ./k8s/gaia-statefulset.yaml | kubectl apply -f -
	@sed "s/NUM_CHAINS_PLACEHOLDER/$(NODES)/" ./k8s/relayer-deployment.yaml | kubectl apply -f -
	@echo "✅ Initialization complete. You can now check the status with 'make logs'."

start:
	@echo "🚀 Services are already started by Kubernetes deployment. Check logs."

down:
	@echo "🔥 Deleting all Kubernetes resources..."
	@kubectl delete -f ./k8s/gaia-statefulset.yaml
	@kubectl delete -f ./k8s/relayer-deployment.yaml
	@kubectl delete secret gaia-mnemonics
	@kubectl delete configmap gaia-scripts-config relayer-scripts-config

logs:
	@echo "📜 Tailing logs..."
	@kubectl logs -l app=gaia -f
	@kubectl logs -l app=relayer -f

clean:
	@echo "🧹 Cleaning up generated files..."
	@rm -f .env

dashboard-up:
	@echo "🌐 Deploying Kubernetes Dashboard..."
	@kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
	@echo "✅ Kubernetes Dashboard deployed. Run 'make dashboard-setup' to configure access."

dashboard-down:
	@echo "🔥 Deleting Kubernetes Dashboard..."
	@kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.7.0/aio/deploy/recommended.yaml
	@kubectl delete sa dashboard-admin -n kubernetes-dashboard || true
	@kubectl delete clusterrolebinding dashboard-admin-binding || true

dashboard-setup:
	@echo "🛠️ Creating dashboard-admin ServiceAccount and ClusterRoleBinding..."
	@kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard
	@kubectl create clusterrolebinding dashboard-admin-binding --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-admin
	@echo "✅ Setup complete. Run 'make dashboard-token' to retrieve the access token."

dashboard-token:
	@echo "🔑 Retrieving access token for Kubernetes Dashboard..."
	@TOKEN=$$(kubectl create token dashboard-admin -n kubernetes-dashboard) && echo "---" && echo "Access Token:" && echo "$$TOKEN" && echo "---"


# ====================================================================================
# Local Datachain Development
# ====================================================================================

# 変数を定義
APP_NAME := datachain
# 注意: モジュール名はスキャフォールド時に指定した単数形の 'datastore' です
MODULE_NAME := datastore
SIGNER_NAME := creator

# バイナリへのパスを動的に取得
CHAIN_BINARY := $(shell go env GOPATH)/bin/$(APP_NAME)d

CHAIN_ID := $(APP_NAME)
TEST_INDEX := "my-first-cid" # キーとなるID (Protoでは 'index' になります)
# テスト用のデータ（コマンド実行時に自動でBase64エンコードされます）
TEST_DATA_1 := "hello cosmos"
TEST_DATA_2 := "hello updated"
TEST_ACCOUNT := alice

# チェーンの初期設定とスキャフォールディング
create-datachain:
	@echo "--> ⛓️ 	Scaffolding chain: $(APP_NAME)..."
	@ignite scaffold chain $(APP_NAME) --no-module --skip-git
	@( \
		cd $(APP_NAME) && \
		echo "--> 📜 Creating empty swagger config..." && \
		echo "version: v2\nplugins: []" > ./proto/buf.gen.swagger.yaml && \
		echo "--> 📦 Scaffolding module: $(MODULE_NAME)..." && \
		ignite scaffold module $(MODULE_NAME) --dep bank && \
		echo "--> 🗺️ 	Scaffolding map 'chunk' in $(MODULE_NAME) module..." && \
		ignite scaffold map chunk data:bytes --module $(MODULE_NAME) --signer $(SIGNER_NAME) \
	)
	@echo "\n✅ Setup complete. Run 'make start-datachain' to start the blockchain."

# ローカルでブロックチェーンを起動
start-datachain:
	@echo "--> 🚀 Starting blockchain node..."
	@cd $(APP_NAME) && ignite chain serve --reset-once

# プロジェクトディレクトリと関連データを削除
delete-datachain:
	@echo "--> 🗑️ 	Deleting project directory: $(APP_NAME)..."
	@rm -rf $(APP_NAME)
	@echo "--> 🗑️ 	Deleting data directory: ~/.$(APP_NAME)..."
	@rm -rf ~/.$(APP_NAME)
	@echo "\n🎉 Clean complete."

# ====================================================================================
# Datachain Transaction Tests (Makefileからテストを実行)
# ====================================================================================

## ヘルパーターゲット（Makefile内でのみ使用）
check-binary:
	@if ! [ -x "$(CHAIN_BINARY)" ]; then \
		echo "Error: Chain binary not found or not executable at $(CHAIN_BINARY)"; \
		echo "Please run 'make start-datachain' first to build the binary."; \
		exit 1; \
	fi

# トランザクションのテストを一括で実行
test-tx:
	@echo "--> 🧹 Cleaning up previous test chunk to ensure a clean slate..."
	@-$(MAKE) tx-delete > /dev/null 2>&1
	@echo "--> 🕒 Waiting 3s for potential delete to be committed..."
	@sleep 3
	@$(MAKE) tx-create
	@echo "--> 🕒 Waiting 3s for create to be committed..."
	@sleep 3
	@$(MAKE) tx-show
	@$(MAKE) tx-update
	@echo "--> 🕒 Waiting 3s for update to be committed..."
	@sleep 3
	@$(MAKE) tx-show
	@$(MAKE) tx-delete
	@echo "--> 🕒 Waiting 3s for delete to be committed..."
	@sleep 3
	@$(MAKE) tx-show-fail

tx-create: check-binary
	@echo "\n--> 📤 [CREATE] Creating chunk with Index: $(TEST_INDEX)"
	@$(CHAIN_BINARY) tx $(MODULE_NAME) create-chunk $(TEST_INDEX) $(shell echo -n $(TEST_DATA_1) | base64 -w 0) --from $(TEST_ACCOUNT) --chain-id $(CHAIN_ID) --gas auto --gas-adjustment 1.5 -y

tx-update: check-binary
	@echo "\n--> 🔄 [UPDATE] Updating chunk with Index: $(TEST_INDEX)"
	@$(CHAIN_BINARY) tx $(MODULE_NAME) update-chunk $(TEST_INDEX) $(shell echo -n $(TEST_DATA_2) | base64 -w 0) --from $(TEST_ACCOUNT) --chain-id $(CHAIN_ID) --gas auto --gas-adjustment 1.5 -y

tx-delete: check-binary
	@echo "\n--> 🗑️ 	[DELETE] Deleting chunk with Index: $(TEST_INDEX)"
	@$(CHAIN_BINARY) tx $(MODULE_NAME) delete-chunk $(TEST_INDEX) --from $(TEST_ACCOUNT) --chain-id $(CHAIN_ID) --gas auto --gas-adjustment 1.5 -y

tx-show: check-binary
	@echo "\n--> 🔎 [SHOW] Querying chunk with Index: $(TEST_INDEX)"
	@$(CHAIN_BINARY) query $(MODULE_NAME) show-chunk $(TEST_INDEX)

tx-show-fail: check-binary
	@echo "\n--> ❌ [SHOW FAIL] Verifying chunk is deleted..."
	@! $(CHAIN_BINARY) query $(MODULE_NAME) show-chunk $(TEST_INDEX) 2>/dev/null && echo "✅ Correctly not found." || (echo "❌ Error: Chunk still exists." && exit 1)

# ====================================================================================
# Help
# ====================================================================================

help:
	@echo "Usage:"
	@echo ""
	@echo "Kubernetes IBC Environment:"
	@echo " 	make init 					 - Deploys all resources (default 2 nodes)."
	@echo " 	make init NODES=3 			 - Deploys all resources for 3 nodes."
	@echo " 	make down 					 - Deletes all resources from the cluster."
	@echo " 	make logs 					 - Follows the container logs."
	@echo " 	make dashboard-up 			 - Deploys the Kubernetes Dashboard."
	@echo " 	make dashboard-down 			 - Deletes the Kubernetes Dashboard."
	@echo " 	make dashboard-setup 		 - Configures and retrieves access token for the dashboard."
	@echo " 	make dashboard-token 		 - Retrieves the access token for the dashboard."
	@echo ""
	@echo "Local Datachain Development:"
	@echo " 	make create-datachain 		 - Scaffolds the datachain project locally."
	@echo " 	make start-datachain 		 - Starts the local datachain node."
	@echo " 	make delete-datachain 		 - Deletes the datachain project and all related data."
	@echo " 	make test-tx 				 - Runs a sequence of transactions (create, update, delete) to test the module."

