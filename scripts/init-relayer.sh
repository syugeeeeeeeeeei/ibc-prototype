#!/bin/sh
set -e

# --- 環境変数と設定 ---
# Helmのテンプレートから環境変数が渡されることを想定
# 例: "ibc-app-chain-0,ibc-app-chain-1"
CHAIN_NAMES_CSV=${CHAIN_NAMES_CSV}
# 例: "ibc-app-chain-headless"
HEADLESS_SERVICE_NAME=${HEADLESS_SERVICE_NAME}

RELAYER_HOME="/home/relayer/.relayer"
KEY_NAME="relayer"
DENOM="uatom"
PATH_PREFIX="path"
# ニーモニックはSecretからマウントされることを想定
MNEMONICS_DIR="/etc/relayer/mnemonics"

# --- 必須変数のチェック ---
if [ -z "$CHAIN_NAMES_CSV" ] || [ -z "$HEADLESS_SERVICE_NAME" ]; then
  echo "Error: CHAIN_NAMES_CSV and HEADLESS_SERVICE_NAME must be set."
  exit 1
fi

# --- リレイヤーの初期化 ---
echo "--- Initializing relayer configuration ---"
if [ ! -f "$RELAYER_HOME/config/config.yaml" ]; then
    rly config init
fi
sed -i 's/timeout: 10s/timeout: 30s/' "$RELAYER_HOME/config/config.yaml"
sed -i 's/memo: ""/memo: "relayed by k8s"/' "$RELAYER_HOME/config/config.yaml"

# CSVをスペース区切りのリストに変換
CHAIN_IDS=$(echo "$CHAIN_NAMES_CSV" | tr ',' ' ')

# --- ループ処理で全チェーンの情報を追加 ---
echo "--- Adding chain configurations ---"
for CHAIN_ID in $CHAIN_IDS; do
    RPC_ADDR="http://${CHAIN_ID}.${HEADLESS_SERVICE_NAME}:26657"
    GRPC_ADDR="${CHAIN_ID}.${HEADLESS_SERVICE_NAME}:9090"

    echo "--> Adding chain: $CHAIN_ID"
    rly chains add \
        --file - \
        "$CHAIN_ID" <<EOF
{
  "type": "cosmos",
  "value": {
    "key": "$KEY_NAME",
    "chain-id": "$CHAIN_ID",
    "rpc-addr": "$RPC_ADDR",
    "grpc-addr": "$GRPC_ADDR",
    "account-prefix": "cosmos",
    "keyring-backend": "test",
    "gas-adjustment": 1.5,
    "gas-prices": "0.001$DENOM",
    "debug": false,
    "timeout": "20s",
    "output-format": "json",
    "sign-mode": "direct"
  }
}
EOF
done

# --- ループ処理で全キーをリストア ---
echo "--- Restoring relayer keys ---"
for CHAIN_ID in $CHAIN_IDS; do
    MNEMONIC_FILE="${MNEMONICS_DIR}/${CHAIN_ID}.mnemonic"

    echo "--> Waiting for mnemonic for ${CHAIN_ID}..."
    while [ ! -f "$MNEMONIC_FILE" ]; do sleep 1; done

    RELAYER_MNEMONIC=$(cat "$MNEMONIC_FILE")
    rly keys restore "$CHAIN_ID" "$KEY_NAME" "$RELAYER_MNEMONIC"
done

# --- 資金がアカウントに反映されるのを待つ ---
echo "--- Waiting for funds to be available on all chains... ---"
sleep 15

# --- 全チェーン間のIBCパスを総当たりで作成・接続 ---
echo "--- Creating and linking all IBC paths ---"
CHAIN_IDS_ARRAY=($CHAIN_IDS)
for (( i=0; i<${#CHAIN_IDS_ARRAY[@]}; i++ )); do
  for (( j=i+1; j<${#CHAIN_IDS_ARRAY[@]}; j++ )); do
    CHAIN1_ID=${CHAIN_IDS_ARRAY[$i]}
    CHAIN2_ID=${CHAIN_IDS_ARRAY[$j]}
    PATH_NAME="${PATH_PREFIX}-${CHAIN1_ID}-to-${CHAIN2_ID}"

    echo "--> Creating path: $PATH_NAME"
    rly paths new "$CHAIN1_ID" "$CHAIN2_ID" "$PATH_NAME" \
        --src-port transfer --dst-port transfer \
        --order unordered --version ics20-1

    echo "--> Linking path: $PATH_NAME"
    # 本番環境ではより堅牢な待機・リトライ処理が必要
    rly transact link "$PATH_NAME" --debug || echo "Warning: Failed to link $PATH_NAME, will retry or continue."
  done
done

# --- 全パスのリレイヤーを起動 ---
echo "--- Starting relayers for all paths ---"
# `rly start`は単一のパスしか指定できないため、全パスを指定して起動
# パス名は `rly paths list` で取得できる
exec rly start $(rly paths list -j | jq -r 'keys | .[]' | tr '\n' ' ') --debug