#!/bin/sh
set -e

# --- 環境変数と設定 ---
CHAIN_NAMES_CSV=${CHAIN_NAMES_CSV}
HEADLESS_SERVICE_NAME=${HEADLESS_SERVICE_NAME}
POD_NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)
RELEASE_NAME=${RELEASE_NAME:-ibc-app}

RELAYER_HOME="/home/relayer/.relayer"
KEY_NAME="relayer"
DENOM="uatom"
PATH_PREFIX="path"
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

# CSVをスペース区切りのリストに変換
CHAIN_IDS=$(echo "$CHAIN_NAMES_CSV" | tr ',' ' ')

# --- ループ処理で全チェーンの情報を追加 ---
echo "--- Adding chain configurations ---"
TMP_DIR="/tmp/relayer-configs"
mkdir -p "$TMP_DIR"
trap 'rm -rf -- "$TMP_DIR"' EXIT

for CHAIN_ID in $CHAIN_IDS; do
    POD_HOSTNAME="${RELEASE_NAME}-${CHAIN_ID}-0"
    RPC_ADDR="http://${POD_HOSTNAME}.${HEADLESS_SERVICE_NAME}.${POD_NAMESPACE}.svc.cluster.local:26657"
    GRPC_ADDR="${POD_HOSTNAME}.${HEADLESS_SERVICE_NAME}.${POD_NAMESPACE}.svc.cluster.local:9090"
    TMP_JSON_FILE="${TMP_DIR}/${CHAIN_ID}.json"

    echo "--> Adding chain: $CHAIN_ID (connecting to ${POD_HOSTNAME})"

    cat > "$TMP_JSON_FILE" <<EOF
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

    rly chains add --file "$TMP_JSON_FILE"
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
for CHAIN_ID in $CHAIN_IDS; do
    echo "--> Checking balance for $CHAIN_ID"
    while true; do
        # ★★★★★★★★★★★★★★★★★★★★★★★★★
        # ★★★ これが最も重要な修正点です ★★★
        # ★★★★★★★★★★★★★★★★★★★★★★★★★
        # `rly q balance`を実行し、エラーも含めて出力をキャプチャ
        balance_output=$(rly q balance "$CHAIN_ID" 2>&1 || true)
        
        # 正常に残高が取得できたかチェック
        if echo "${balance_output}" | grep -q "${DENOM}$"; then
            balance=$(echo "${balance_output}" | grep "${DENOM}$" | sed 's/[^0-9]*//g' || echo "0")
            balance=${balance:-0}

            if [ "$balance" -gt 0 ]; then
                echo "--> Funds are available on $CHAIN_ID: $balance$DENOM"
                break # 成功したのでループを抜ける
            fi
        else
            # 正常な応答ではない場合、一時的なエラーか表示して待機を続ける
            echo "    Chain not fully ready yet. Retrying... (Reason: ${balance_output})"
        fi
        
        sleep 5
    done
done


# --- 全チェーン間のIBCパスを総当たりで作成・接続 ---
echo "--- Creating and linking all IBC paths ---"
CHAIN_IDS_ARRAY=($CHAIN_IDS)
for (( i=0; i<${#CHAIN_IDS_ARRAY[@]}; i++ )); do
  for (( j=i+1; j<${#CHAIN_IDS_ARRAY[@]}; j++ )); do
    CHAIN1_ID=${CHAIN_IDS_ARRAY[$i]}
    CHAIN2_ID=${CHAIN_IDS_ARRAY[$j]}
    PATH_NAME="${PATH_PREFIX}-${CHAIN1_ID}-to-${CHAIN2_ID}"

    echo "--> Creating path: $PATH_NAME"
    # rly v2.6.0 では --src-port と --dst-port が非推奨になったため、port transfer を使用
    rly paths new "$CHAIN1_ID" "$CHAIN2_ID" "$PATH_NAME" --port transfer --version ics20-1

    echo "--> Linking path: $PATH_NAME"
    MAX_RETRIES=5
    RETRY_COUNT=0
    SUCCESS=false
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if rly transact link "$PATH_NAME" --debug; then
            echo "--> Successfully linked $PATH_NAME"
            SUCCESS=true
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            echo "Warning: Failed to link $PATH_NAME. Retrying (${RETRY_COUNT}/${MAX_RETRIES})..."
            sleep 10
        fi
    done

    if [ "$SUCCESS" = false ]; then
        echo "Error: Failed to link path $PATH_NAME after $MAX_RETRIES retries."
    fi
  done
done

# --- 全パスのリレイヤーを起動 ---
echo "--- Starting relayers for all configured paths ---"
exec rly start --debug