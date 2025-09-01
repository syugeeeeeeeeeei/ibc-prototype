.PHONY: init start down logs clean help dashboard-up dashboard-down dashboard-token dashboard-setup

.DEFAULT_GOAL := help

# K8sクラスタへのデプロイ
NODES ?= 2

init:
	@echo "🔑 Generating and deploying Kubernetes Secret for mnemonics..."
	@deno run --allow-all ./mnemonic-generator/generate.ts $(NODES) | kubectl apply -f -
	@echo "🛠️  Creating ConfigMaps from scripts..."
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

help:
	@echo "Usage:"
	@echo "  make init          - Deploys all resources (default 2 nodes)."
	@echo "  make init NODES=3  - Deploys all resources for 3 nodes."
	@echo "  make down          - Deletes all resources from the cluster."
	@echo "  make logs          - Follows the container logs."
	@echo "  make dashboard-up  - Deploys the Kubernetes Dashboard."
	@echo "  make dashboard-down- Deletes the Kubernetes Dashboard."
	@echo "  make dashboard-setup- Configures and retrieves access token for the dashboard."
	@echo "  make dashboard-token- Retrieves the access token for the dashboard."