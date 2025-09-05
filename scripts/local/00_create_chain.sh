#!/bin/bash
# エラーが発生した場合や未定義の変数を使用した場合にスクリプトを終了させます
set -euo pipefail

# 共通の環境変数を読み込みます
# スクリプトの場所を基準にenv.shを読み込むため、どこから実行されても安心です
source "$(dirname "$0")/../env.sh"

# --- Main Script ---

# 既存のプロジェクトディレクトリが存在する場合は、競合を避けるために削除します
if [ -d "${APP_NAME}" ]; then
    echo "--> 🗑️  Found existing project directory. Cleaning up '${APP_NAME}' before scaffolding..."
    rm -rf "${APP_NAME}"
fi

echo "--> ⛓️   Step 1/5: Scaffolding base chain: '${APP_NAME}'..."
ignite scaffold chain "${APP_NAME}" --skip-git
echo "--> ✅ Done."

cd "${APP_NAME}"
echo "--> 📁 Entered project directory: '$(pwd)'"

echo "--> 📜 Step 2/5: Creating empty swagger config..."
echo "version: v2
plugins: []" > ./proto/buf.gen.swagger.yaml
echo "--> ✅ Done."

echo "--> ⚛️   Step 3/5: Scaffolding IBC-enabled module '${MODULE_NAME}'..."
# まず --ibc フラグを使って、IBC対応のモジュールを作成する
ignite scaffold module "${MODULE_NAME}" --ibc
echo "--> ✅ Done."

echo "--> 📦 Step 4/5: Scaffolding 'chunk' packet into '${MODULE_NAME}'..."
# 次に、作成したIBCモジュールにパケットを追加する
ignite scaffold packet chunk index:string data:bytes --module "${MODULE_NAME}"
echo "--> ✅ Done."

echo "--> 🗺️   Step 5/5: Scaffolding KVS map 'stored-chunk' into '${MODULE_NAME}' module..."
# KVSマップの名前を 'chunk' から 'storedChunk' へ変更して衝突を回避
ignite scaffold map stored-chunk data:bytes --module "${MODULE_NAME}" --signer "${SIGNER_NAME}"
echo "--> ✅ Done."


echo -e "\n🎉 Successfully created an IBC-enabled datachain project."
echo "   You can now run 'make start-datachain' to launch the node."