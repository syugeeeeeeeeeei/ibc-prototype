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
    ATTEMPTS=0
    MAX_ATTEMPTS=20 # タイムアウトを延長
    until rly q balance "$CHAIN_ID" > /dev/null 2>&1; do
        ATTEMPTS=$((ATTEMPTS + 1))
        if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
          echo "!!! Timed out waiting for funds on $CHAIN_ID !!!"
          # exit 1
        fi
        echo "    Waiting for funds on $CHAIN_ID... (Attempt $ATTEMPTS/$MAX_ATTEMPTS)"
        sleep 5
    done
    echo "--> Funds are available on $CHAIN_ID"
done


# --- アプリケーション固有のIBCパスを作成・接続 ---
echo "--- Creating and linking application-specific IBC paths ---"

META_CHAIN_ID=""
DATA_CHAIN_IDS=""
for CHAIN_ID in $CHAIN_IDS; do
  if [[ $CHAIN_ID == meta-* ]]; then
    META_CHAIN_ID=$CHAIN_ID
  else
    DATA_CHAIN_IDS="$DATA_CHAIN_IDS $CHAIN_ID"
  fi
done

if [ -z "$META_CHAIN_ID" ]; then
  echo "Error: No 'meta' chain found in CHAIN_NAMES_CSV."
  exit 1
fi

for DATA_CHAIN_ID in $DATA_CHAIN_IDS; do
    PATH_NAME="${PATH_PREFIX}-${DATA_CHAIN_ID}-to-${META_CHAIN_ID}"

    # ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
    # ★★★ これが最も重要な修正点です (1/2) ★★★
    # ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
    # gaiaのサンプルを参考に、rly paths new コマンドに全ての情報をフラグで渡します。
    # これにより、`datastore`と`metastore`というカスタムポートを持つパス定義が正しく生成されます。
    echo "--> Creating new IBC path definition: $PATH_NAME"
    rly paths new "$DATA_CHAIN_ID" "$META_CHAIN_ID" "$PATH_NAME" --src-port datastore --dst-port metastore --order unordered --version "ics20-1"

    # ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
    # ★★★ これが最も重要な修正点です (2/2) ★★★
    # ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
    # gaiaのサンプルを参考に、堅牢な再試行ループを実装します。
    # これにより、チェーンの準備が整うタイミングのズレを吸収し、確実にリンクを確立します。
    echo "--> Attempting to link path: $PATH_NAME"
    ATTEMPTS=0
    MAX_ATTEMPTS=5
    SUCCESS=false
    until $SUCCESS; do
        if rly transact link "$PATH_NAME" --debug; then
            echo "✅ Successfully linked $PATH_NAME"
            SUCCESS=true
        else
            ATTEMPTS=$((ATTEMPTS + 1))
            if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
                echo "!!! Failed to link path $PATH_NAME after $MAX_ATTEMPTS attempts. !!!"
                # exit 1 # 失敗したらコンテナを終了させる
            fi
            echo "    Link failed. Retrying in 10 seconds... (Attempt $ATTEMPTS/$MAX_ATTEMPTS)"
            sleep 10
        fi
    done
done

# --- 全パスのリレイヤーを起動 ---
echo "--- Starting relayers for all configured paths ---"
exec rly start --debug