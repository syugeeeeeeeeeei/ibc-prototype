#!/bin/bash
set -e

# --- 設定 ---
RELEASE_NAME="ibc-app"
RELAYER_POD=$(kubectl get pods -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/component=relayer" -o jsonpath='{.items[0].metadata.name}')
DATA_0_POD="${RELEASE_NAME}-data-0-0"
DATA_1_POD="${RELEASE_NAME}-data-1-0"
META_0_POD="${RELEASE_NAME}-meta-0-0"

DATA_0_CMD="kubectl exec -i ${DATA_0_POD} -- datachaind"
DATA_1_CMD="kubectl exec -i ${DATA_1_POD} -- datachaind"
META_0_CMD="kubectl exec -i ${META_0_POD} -- metachaind"

TX_FLAGS_DATA_0="--chain-id ${DATA_0_POD} --keyring-backend test --output json --gas auto --gas-adjustment 1.5 --gas-prices 0.001uatom --yes"
TX_FLAGS_DATA_1="--chain-id ${DATA_1_POD} --keyring-backend test --output json --gas auto --gas-adjustment 1.5 --gas-prices 0.001uatom --yes"
TX_FLAGS_META_0="--chain-id ${META_0_POD} --keyring-backend test --output json --gas auto --gas-adjustment 1.5 --gas-prices 0.001uatom --yes"

# テストごとにユニークなIDを生成するためのサフィックス
UNIQUE_SUFFIX=$(date +%s)

echo "--- 🚀 Test Scenario Start ---"

# --- Step 1: data-0 に "Hello" を保存 ---
echo "--- 📦 Storing 'Hello' on data-0... ---"
DATA_0_INDEX="hello-${UNIQUE_SUFFIX}"
DATA_0_HEX=$(printf '%s' "Hello" | xxd -p -c 256)
${DATA_0_CMD} tx datastore create-stored-chunk "${DATA_0_INDEX}" "${DATA_0_HEX}" --from creator ${TX_FLAGS_DATA_0} > /dev/null
echo "✅ Stored 'Hello' on data-0 at index: ${DATA_0_INDEX}"
sleep 5

# --- Step 2: data-1 に "World" を保存 ---
echo "--- 📦 Storing 'World' on data-1... ---"
DATA_1_INDEX="world-${UNIQUE_SUFFIX}"
DATA_1_HEX=$(printf '%s' "World" | xxd -p -c 256)
${DATA_1_CMD} tx datastore create-stored-chunk "${DATA_1_INDEX}" "${DATA_1_HEX}" --from creator ${TX_FLAGS_DATA_1} > /dev/null
echo "✅ Stored 'World' on data-1 at index: ${DATA_1_INDEX}"
sleep 5

# --- Step 3: IBCチャネル情報をRelayerから取得 ---
echo "--- 📡 Getting IBC channel info from relayer... ---"
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# ★★★ これが最も重要な修正点です ★★★
# ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
# init-relayer.sh で作成した 'path-data-0-to-meta-0' のパス情報を取得します。
# このパスでは meta-0 が宛先(dst)となっているため、jq で .chains.dst.channel_id を
# 取得することで、meta-0 側のチャネルIDが得られます。
# 変数名のタイポを修正し、冗長な呼び出しを削除しました。
META_CHANNEL_ID=$(\
  kubectl exec -i ${RELAYER_POD} -- rly paths show "path-data-0-to-meta-0" --json | \
  jq -r '.chains.dst.channel_id'
)

if [ -z "${META_CHANNEL_ID}" ] || [ "${META_CHANNEL_ID}" == "null" ]; then
    echo "🔥 Error: Failed to get channel ID from relayer. Path 'path-data-0-to-meta-0' may not be linked correctly."
    exit 1
fi

echo "✅ Found channel on meta-0 for IBC transfer: ${META_CHANNEL_ID}"

# --- Step 4: meta-0 からメタデータをIBCで送信 ---
echo "--- ✉️  Sending metadata packet from meta-0... ---"
# send-metadataコマンドでIBCパケットを送信する
# ※ 'accepts 4 arg(s)' エラーは、上の META_CHANNEL_ID が空だったことが原因のため、この行は修正不要です。
${META_0_CMD} tx metastore send-metadata metastore ${META_CHANNEL_ID} "HelloWorld.com" "${DATA_0_INDEX},${DATA_1_INDEX}" --from creator ${TX_FLAGS_META_0} > /dev/null
echo "✅ Metadata packet sent. Waiting for relayer to process..."
sleep 15

# --- Step 5: meta-0 にデータが保存されたか確認 ---
echo "--- 🔍 Verifying result on meta-0... ---"
VERIFICATION_RESULT=$(${META_0_CMD} query metastore list-stored-meta --output json | jq -r '.storedMeta[] | select(.url == "HelloWorld.com")')

if [ -n "${VERIFICATION_RESULT}" ]; then
  echo "--- 🎉 SUCCESS! Test Scenario Completed ---"
  echo "Found stored metadata on meta-0:"
  echo "${VERIFICATION_RESULT}"
else
  echo "--- 🔥 FAILURE! Test Scenario Failed ---"
  echo "Could not find stored metadata for 'HelloWorld.com' on meta-0."
  exit 1
fi