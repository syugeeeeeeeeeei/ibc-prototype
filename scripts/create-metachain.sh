#!/bin/bash
# エラーが発生した場合や未定義の変数を使用した場合にスクリプトを終了させます
set -euo pipefail

# --- 設定 ---
CHAIN_DIR="chain"
APP_NAME="metachain"
MODULE_NAME="metastore"
SIGNER_NAME="creator"
PROJECT_PATH="${CHAIN_DIR}/${APP_NAME}"

# --- メインスクリプト ---
echo "--- metachainのセットアップを開始します ---"

# 既存のプロジェクトディレクトリが存在する場合は、競合を避けるために削除します
if [ -d "${PROJECT_PATH}" ]; then
    echo "--> 🗑️  既存のプロジェクトディレクトリをクリーンアップします: '${PROJECT_PATH}'"
    rm -rf "${PROJECT_PATH}"
fi

# chainディレクトリがなければ作成
mkdir -p "${CHAIN_DIR}"
cd "${CHAIN_DIR}"

echo "--> ⛓️  Step 1/5: ベースとなるチェーンをscaffoldで生成します: '${APP_NAME}'..."
ignite scaffold chain "${PROJECT_PATH}" --skip-git --no-module
echo "--> ✅完了"

cd "../${PROJECT_PATH}"
echo "--> 📁 プロジェクトディレクトリに移動しました: '$(pwd)'"

echo "--> 📜 Step 2/5: swagger設定ファイルを作成します..."
# protoディレクトリが存在しない場合は作成
mkdir -p ./proto
echo "version: v2
plugins: []" > ./proto/buf.gen.swagger.yaml
echo "--> ✅完了"

echo "--> ⚛️  Step 3/5: IBC対応モジュールをscaffoldで生成します: '${MODULE_NAME}'..."
ignite scaffold module "${MODULE_NAME}" --ibc --dep bank
echo "--> ✅完了"

echo "--> 📦 Step 4/5: '${MODULE_NAME}'に'metadata'パケットをscaffoldで生成します..."
ignite scaffold packet metadata url:string addresses:array.string --module "${MODULE_NAME}"
echo "--> ✅完了"

echo "--> 🗺️  Step 5/5: '${MODULE_NAME}'モジュールにKVSマップ'stored-meta'をscaffoldで生成します..."
ignite scaffold map stored-meta url:string --module "${MODULE_NAME}" --signer "${SIGNER_NAME}"
echo "--> ✅完了"

echo -e "\n🎉 metachainプロジェクトの作成が成功しました: '${PROJECT_PATH}'"

