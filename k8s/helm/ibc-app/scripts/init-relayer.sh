#!/bin/sh
set -e

# --- 環境変数と設定 ---
CHAIN_NAMES_CSV=${CHAIN_NAMES_CSV}
HEADLESS_SERVICE_NAME=${HEADLESS_SERVICE_NAME}

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
# 一時ファイルを作成するためのディレクトリを準備
# mktempコマンドがない環境を考慮し、固定パスにする
TMP_DIR="/tmp/relayer-configs"
mkdir -p "$TMP_DIR"
# スクリプト終了時に一時ディレクトリをクリーンアップする
trap 'rm -rf -- "$TMP_DIR"' EXIT

for CHAIN_ID in $CHAIN_IDS; do
    RPC_ADDR="http://${CHAIN_ID}.${HEADLESS_SERVICE_NAME}:26657"
    GRPC_ADDR="${CHAIN_ID}.${HEADLESS_SERVICE_NAME}:9090"
    TMP_JSON_FILE="${TMP_DIR}/${CHAIN_ID}.json"

    echo "--> Adding chain: $CHAIN_ID"

    # ★★★★★★★★★★★★★★★★★★★★★★★★★
    # ★★★ 修正箇所: ここから ★★★
    # ★★★★★★★★★★★★★★★★★★★★★★★★★
    # --file - が機能しないバージョン向けの対応。
    # 一時的にJSONファイルを作成する。
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

    # 作成した一時ファイルを指定してチェーンを追加
    rly chains add --file "$TMP_JSON_FILE" "$CHAIN_ID"
    # ★★★★★★★★★★★★★★★★★★★★★★★★★
    # ★★★ 修正箇所: ここまで ★★★
    # ★★★★★★★★★★★★★★★★★★★★★★★★★
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
        # rly q balanceはエラー時にnon-zeroでexitするため `|| true` をつける
        balance=$(rly q balance "$CHAIN_ID" --denom "$DENOM" 2>/dev/null | awk '{print $1}' || echo "0")
        if [ "$balance" -gt 0 ]; then
            echo "--> Funds are available on $CHAIN_ID: $balance$DENOM"
            break
        else
            echo "--> Waiting for funds on $CHAIN_ID..."
            sleep 5
        fi
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
    rly paths new "$CHAIN1_ID" "$CHAIN2_ID" "$PATH_NAME" \
        --src-port transfer --dst-port transfer \
        --order unordered --version ics20-1

    echo "--> Linking path: $PATH_NAME"
    # リンクの成功/リトライ処理
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
        # 必要に応じてexit 1を追加
    fi
  done
done

# --- 全パスのリレイヤーを起動 ---
echo "--- Starting relayers for all configured paths ---"
exec rly start --debug