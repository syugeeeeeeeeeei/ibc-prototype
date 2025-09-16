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

TX_FLAGS_DATA_0="--chain-id data-0 --keyring-backend test --output json --gas auto --gas-adjustment 1.5 --gas-prices 0.001uatom --yes"
TX_FLAGS_DATA_1="--chain-id data-1 --keyring-backend test --output json --gas auto --gas-adjustment 1.5 --gas-prices 0.001uatom --yes"
TX_FLAGS_META_0="--chain-id meta-0 --keyring-backend test --output json --gas auto --gas-adjustment 1.5 --gas-prices 0.001uatom --yes"

UNIQUE_SUFFIX=$(date +%s)

echo "--- 🚀 Test Scenario Start ---"
# --- Step 1 & 2: データを各チェーンに保存 ---
echo "--- 📦 Storing 'Hello' on data-0... ---"
DATA_0_INDEX="hello-${UNIQUE_SUFFIX}"
DATA_0_HEX=$(printf '%s' "Hello" | xxd -p -c 256)
${DATA_0_CMD} tx datastore create-stored-chunk "${DATA_0_INDEX}" "${DATA_0_HEX}" --from creator ${TX_FLAGS_DATA_0} | jq '.'
sleep 5

echo "--- 📦 Storing 'World' on data-1... ---"
DATA_1_INDEX="world-${UNIQUE_SUFFIX}"
DATA_1_HEX=$(printf '%s' "World" | xxd -p -c 256)
${DATA_1_CMD} tx datastore create-stored-chunk "${DATA_1_INDEX}" "${DATA_1_HEX}" --from creator ${TX_FLAGS_DATA_1} | jq '.'
sleep 5

# --- Step 3: カスタムIBCチャネルが確立されるのを待機 ---
echo "--- ⏳ Waiting for custom IBC channel (port: metastore) to be open... ---"
META_CHANNEL_ID=""
ATTEMPTS=0
MAX_ATTEMPTS=20
until [ -n "${META_CHANNEL_ID}" ]; do
    # rlyから 'metastore' ポートを持つチャネル情報を取得しようと試みる
    # `-s` オプションで複数のJSONオブジェクトを配列として読み込む
    CHANNEL_INFO_JSON=$(kubectl exec -i ${RELAYER_POD} -- rly q channels meta-0 --output json | jq -s 'map(select(.port_id == "metastore" and .state == "STATE_OPEN")) | .[0] // empty')

    if [ -n "${CHANNEL_INFO_JSON}" ]; then
        META_CHANNEL_ID=$(echo "${CHANNEL_INFO_JSON}" | jq -r '.channel_id')
        echo "✅ Found open channel on meta-0 for port 'metastore': ${META_CHANNEL_ID}"
        break
    fi

    ATTEMPTS=$((ATTEMPTS + 1))
    if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
        echo "🔥 Error: Timed out waiting for channel with port 'metastore'. Please check the relayer logs." >&2
        kubectl logs ${RELAYER_POD} --tail=100
        exit 1
    fi
    echo "    Channel not ready yet. Retrying in 10 seconds... (Attempt $ATTEMPTS/$MAX_ATTEMPTS)"
    sleep 10
done

# --- Step 4: meta-0 からメタデータをIBCで送信 ---
echo "--- ✉️  Sending metadata packet from meta-0... ---"
TX_OUTPUT_META_0=$(${META_0_CMD} tx metastore send-metadata metastore ${META_CHANNEL_ID} "HelloWorld.com" "${DATA_0_INDEX},${DATA_1_INDEX}" --from creator ${TX_FLAGS_META_0})
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
  exit 1
fi