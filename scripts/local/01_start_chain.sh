#!/bin/bash
set -euo pipefail

# 共通の環境変数を読み込みます
source "$(dirname "$0")/../env.sh"

# プロジェクトディレクトリが存在するか確認します
if [ ! -d "${APP_NAME}" ]; then
    echo "Error: Project directory '${APP_NAME}' not found."
    echo "Please run 'make create-datachain' first."
    exit 1
fi

echo "--> 🚀 Starting blockchain node: ${APP_NAME}..."
cd "${APP_NAME}"
# --reset-once フラグは、前回のデータをクリーンアップして起動する際に便利です
ignite chain serve --reset-once --skip-proto