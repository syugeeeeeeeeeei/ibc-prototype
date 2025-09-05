#!/bin/bash
set -euo pipefail

# 共通の環境変数を読み込みます
source "$(dirname "$0")/../env.sh"

echo "--> 🗑️   Deleting project directory: ${APP_NAME}..."
sudo rm -rf "${APP_NAME}"

echo "--> 🗑️   Deleting data directory: ~/.${APP_NAME}..."
sudo rm -rf "$HOME/.${APP_NAME}"

echo -e "\n🎉 Clean complete."