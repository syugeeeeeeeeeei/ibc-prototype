#!/bin/bash
set -e

# --- デバッグモードを有効にする ---
set -x

# --- 設定 ---
RELEASE_NAME="ibc-app"
RELAYER_POD=$(kubectl get pods -l "app.kubernetes.io/instance=${RELEASE_NAME},app.kubernetes.io/component=relayer" -o jsonpath='{.items[0].metadata.name}')
DATA_0_POD="${RELEASE_NAME}-data-0-0"
DATA_1_POD="${RELEASE_NAME}-data-1-0"
META_0_POD="${RELEASE_NAME}-meta-0-0"

DATA_0_CMD="kubectl exec -i ${DATA_0_POD} -- datachaind"
DATA_1_CMD="kubectl exec -i ${DATA_1_POD} -- datachaind"
META_0_CMD="kubectl exec -i ${META_0_POD} -- metachaind"

# ★★★ 修正箇所 ★★★
# Pod名ではなく、正しいchain-idに修正します
TX_FLAGS_DATA_0="--chain-id data-0 --keyring-backend test --output json --gas auto --gas-adjustment 1.5 --gas-prices 0.001uatom --yes"
TX_FLAGS_DATA_1="--chain-id data-1 --keyring-backend test --output json --gas auto --gas-adjustment 1.5 --gas-prices 0.001uatom --yes"
TX_FLAGS_META_0="--chain-id meta-0 --keyring-backend test --output json --gas auto --gas-adjustment 1.5 --gas-prices 0.001uatom --yes"

UNIQUE_SUFFIX=$(date +%s)

echo "--- 🚀 Test Scenario Start ---"
# --- Step 1: data-0 に "Hello" を保存 ---
echo "--- 📦 Storing 'Hello' on data-0... ---"
DATA_0_INDEX="hello-${UNIQUE_SUFFIX}"
DATA_0_HEX=$(printf '%s' "Hello" | xxd -p -c 256)

TX_OUTPUT_DATA_0=$(${DATA_0_CMD} tx datastore create-stored-chunk "${DATA_0_INDEX}" "${DATA_0_HEX}" --from creator ${TX_FLAGS_DATA_0})
echo "✅ datachaind tx datastore create-stored-chunk completed."
echo "--- Transaction Output for data-0 ---"
echo "${TX_OUTPUT_DATA_0}" | jq '.'
echo "------------------------------------"
sleep 5

# --- Step 2: data-1 に "World" を保存 ---
echo "--- 📦 Storing 'World' on data-1... ---"
DATA_1_INDEX="world-${UNIQUE_SUFFIX}"
DATA_1_HEX=$(printf '%s' "World" | xxd -p -c 256)

TX_OUTPUT_DATA_1=$(${DATA_1_CMD} tx datastore create-stored-chunk "${DATA_1_INDEX}" "${DATA_1_HEX}" --from creator ${TX_FLAGS_DATA_1})
echo "✅ datachaind tx datastore create-stored-chunk completed."
echo "--- Transaction Output for data-1 ---"
echo "${TX_OUTPUT_DATA_1}" | jq '.'
echo "------------------------------------"
sleep 5

# --- 💡 IBC接続が確立されるのを待機 ---
echo "--- ⏳ Waiting for IBC connection and channel to be open... ---"
# connection-0 が STATE_OPEN になるまで待機
CONNECTION_STATUS=""
while [ "${CONNECTION_STATUS}" != "STATE_OPEN" ]; do
    echo "Waiting for connection-0 to be open..."
    # `|| true` を追加することで、jqが失敗してもスクリプトが停止しないようにする
    CONNECTION_STATUS=$(kubectl exec -i ${META_0_POD} -- metachaind query ibc connection end connection-0 --output json | jq -r '.connection.state' || true)
    sleep 5
done
echo "✅ Connection is open."

# channel-0 が STATE_OPEN になるまで待機
CHANNEL_STATUS=""
while [ "${CHANNEL_STATUS}" != "STATE_OPEN" ]; do
    echo "Waiting for channel-0 to be open..."
    CHANNEL_STATUS=$(kubectl exec -i ${META_0_POD} -- metachaind query ibc channel end transfer channel-0 --output json | jq -r '.channel.state' || true)
    sleep 5
done
echo "✅ Channel is open."

# --- Step 3: IBCチャネル情報をRelayerから取得 ---
echo "--- 📡 Getting IBC channel info from relayer... ---"
# `rly`の出力からチャンネルIDを安全に取得
META_CHANNEL_ID_RAW=$(kubectl exec -i ${RELAYER_POD} -- rly q channels meta-0)

echo "--- Relayer Channel Query Output ---"
echo "${META_CHANNEL_ID_RAW}" | jq -r -s '.'
META_CHANNEL_ID=$(echo "${META_CHANNEL_ID_RAW}" | jq -r -s '.[0].channel_id')

if [ -z "${META_CHANNEL_ID}" ] || [ "${META_CHANNEL_ID}" == "null" ]; then
    echo "🔥 Error: Failed to get channel ID from relayer. The channel for 'meta-0' on port 'metastore' may not be linked correctly." >&2
    exit 1
fi

echo "✅ Found channel on meta-0 for IBC transfer: ${META_CHANNEL_ID}"
echo "--- ✉️  Sending metadata packet from meta-0... ---"

# --- Step 4: meta-0 からメタデータをIBCで送信 ---
# ★★★ 修正箇所 ★★★
# ポートIDを正しく指定


sleep 30

TX_OUTPUT_META_0=$(${META_0_CMD} tx metastore send-metadata transfer ${META_CHANNEL_ID} "HelloWorld.com" "${DATA_0_INDEX},${DATA_1_INDEX}" --from creator ${TX_FLAGS_META_0})

echo "✅ metachaind tx metastore send-metadata completed."
echo "--- Transaction Output for meta-0 ---"
echo "${TX_OUTPUT_META_0}" | jq '.'
echo "-----------------------------------"
echo "✅ Metadata packet sent. Waiting for relayer to process..."
sleep 15

# --- Step 5: meta-0 にデータが保存されたか確認 ---
echo "--- 🔍 Verifying result on meta-0... ---"
VERIFICATION_RESULT_RAW=$(${META_0_CMD} query metastore list-stored-meta --output json)
VERIFICATION_RESULT=$(echo "${VERIFICATION_RESULT_RAW}" | jq -r '.storedMeta[] | select(.url == "HelloWorld.com")')

echo "--- Query Result from meta-0 ---"
echo "${VERIFICATION_RESULT_RAW}" | jq '.'
echo "--------------------------------"

if [ -n "${VERIFICATION_RESULT}" ]; then
  echo "--- 🎉 SUCCESS! Test Scenario Completed ---"
  echo "Found stored metadata on meta-0:"
  echo "${VERIFICATION_RESULT}"
else
  echo "--- 🔥 FAILURE! Test Scenario Failed ---" >&2
  echo "Could not find stored metadata for 'HelloWorld.com' on meta-0." >&2
  echo "Query result was: ${VERIFICATION_RESULT_RAW}" >&2
  exit 1
fi