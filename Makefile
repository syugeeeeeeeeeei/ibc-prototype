# .PHONY は、同名のファイルが存在してもターゲットを実行するようにするための宣言です
.PHONY: help init start down logs clean \
		dashboard-up dashboard-down dashboard-token dashboard-setup \
		create-datachain start-datachain delete-datachain \
		test-tx

.DEFAULT_GOAL := help

# ====================================================================================
# Kubernetes IBC Environment Management
# ====================================================================================

# K8sクラスタへのデプロイするノード数を指定 (例: make init NODES=3)
NODES ?= 2

init:
	@./scripts/k8s/01_init.sh $(NODES)

down:
	@./scripts/k8s/02_down.sh

logs:
	@./scripts/k8s/03_logs.sh

clean:
	@echo "🧹 Cleaning up generated files..."
	@rm -f .env


# ====================================================================================
# Kubernetes Dashboard Management (Simple commands, can remain in Makefile)
# ====================================================================================

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
	@TOKEN=$$(\
		kubectl create token dashboard-admin -n kubernetes-dashboard \
	) && echo "---" && echo "Access Token:" && echo "$$TOKEN" && echo "---"


# ====================================================================================
# Local Datachain Development
# ====================================================================================

create-datachain:
	@./scripts/local/00_create_chain.sh

start-datachain:
	@./scripts/local/01_start_chain.sh

delete-datachain:
	@./scripts/local/99_delete_chain.sh


# ====================================================================================
# Datachain Transaction Tests
# ====================================================================================

test-tx:
	@./scripts/local/02_test_tx.sh


# ====================================================================================
# Help
# ====================================================================================

help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Kubernetes IBC Environment:"
	@echo "  init              Deploys all resources (default 2 nodes). Use 'make init NODES=3' for 3 nodes."
	@echo "  down              Deletes all resources from the cluster."
	@echo "  logs              Follows the container logs for gaia and relayer."
	@echo "  dashboard-up      Deploys the Kubernetes Dashboard."
	@echo "  dashboard-down    Deletes the Kubernetes Dashboard."
	@echo "  dashboard-setup   Configures access for the dashboard."
	@echo "  dashboard-token   Retrieves the access token for the dashboard."
	@echo ""
	@echo "Local Datachain Development:"
	@echo "  create-datachain  Scaffolds the datachain project locally."
	@echo "  start-datachain   Starts the local datachain node."
	@echo "  delete-datachain  Deletes the datachain project and all related data."
	@echo "  test-tx           Runs a sequence of transactions (create, update, delete) to test the module."