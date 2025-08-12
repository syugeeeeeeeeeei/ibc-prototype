# .PHONY は、ファイル名とターゲット名が衝突するのを防ぐおまじないです
.PHONY: init start up-d down down-v logs clean help

# デフォルトのコマンドを 'help' に設定
.DEFAULT_GOAL := help

# ニーモニックを含む .env ファイルを生成する
.env:
	@echo "🔑 Generating new mnemonics..."
	@(cd mnemonic-generator && yarn ts-node generateMnemonic.ts) > ./.env
	@echo "✅ Mnemonics generated and saved to .env file."

# 環境の完全な初期化を行うメインターゲット
init: down-v clean .env
	@echo "🛠️  Building init image and initializing chain data..."
	@docker-compose --env-file .env up --build --remove-orphans init-node -d
	@echo "✅ Initialization complete. "
	@echo "🌐 Initializing Gaia-1 and Gaia-2 nodes..."
	@make start

# 初期化済みの環境をバックグラウンドで起動する
start:
	@echo "🚀 Starting services in detached mode..."
	@docker-compose up -d gaia-1 gaia-2 ibc-relayer

# startコマンドのエイリアス（別名）
up-d: start

# コンテナを停止
down:
	@echo "🛑 Stopping containers..."
	@docker-compose down

# コンテナを停止し、全データ（ボリューム）を削除
down-v:
	@echo "🔥 Stopping containers and removing all data..."
	@docker-compose down -v

# 全コンテナのログを追跡表示
logs:
	@echo "📜 Tailing logs..."
	@docker-compose logs -f --tail=100

# 生成された .env ファイルを削除
clean:
	@echo "🧹 Cleaning up generated files..."
	@rm -f .env

# ヘルプメッセージを表示
help:
	@echo "Usage:"
	@echo "  make init        - (Run First) Resets everything, generates new keys, and initializes chains."
	@echo "  make start       - Starts the services in the background (after 'make init')."
	@echo "  make up-d        - Alias for 'make start'."
	@echo "  make down        - Stops the services."
	@echo "  make down-v      - Stops services and DELETES ALL DATA."
	@echo "  make logs        - Follows the container logs."
	@echo "  make clean       - Removes generated files."