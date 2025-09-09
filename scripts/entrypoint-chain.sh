#!/bin/sh
set -e

# --- 環境変数と設定 ---
# k8sのStatefulSetによって付与されるホスト名 (例: ibc-app-chain-0) をCHAIN_IDとして使用
CHAIN_ID=${HOSTNAME}
DENOM="uatom"
USER_HOME="/home/datachain"
CHAIN_HOME="$USER_HOME/.datachain"
CHAIN_BINARY="datachaind"
# ニーモニックはSecretからマウントされることを想定
MNEMONIC_FILE="/etc/datachain/mnemonic/key.mnemonic"

# --- 初期化処理 ---
# データディレクトリが存在しない場合のみ初期化処理を実行
if [ ! -d "$CHAIN_HOME/config" ]; then
    echo "--- Initializing chain: $CHAIN_ID ---"

    # 1. チェーンの初期化
    $CHAIN_BINARY init "$CHAIN_ID" --chain-id "$CHAIN_ID" --home "$CHAIN_HOME"

    # 2. デフォルトのdenomを 'stake' から指定されたものに変更
    sed -i "s/\"stake\"/\"$DENOM\"/g" "$CHAIN_HOME/config/genesis.json"

    # 3. Secretからマウントされたニーモニックを使ってキーを復元
    if [ ! -f "$MNEMONIC_FILE" ]; then
        echo "Error: Mnemonic file not found at $MNEMONIC_FILE"
        exit 1
    fi
    VALIDATOR_MNEMONIC=$(cat "$MNEMONIC_FILE")
    echo "$VALIDATOR_MNEMONIC" | $CHAIN_BINARY keys add validator --recover --keyring-backend=test --home "$CHAIN_HOME"
    # リレイヤー用のキーも同じニーモニックから復元 (よりセキュアにする場合は分離も可能)
    echo "$VALIDATOR_MNEMONIC" | $CHAIN_BINARY keys add relayer --recover --keyring-backend=test --home "$CHAIN_HOME"


    # 4. ジェネシスアカウントを追加
    VALIDATOR_ADDR=$($CHAIN_BINARY keys show validator -a --keyring-backend=test --home "$CHAIN_HOME")
    RELAYER_ADDR=$($CHAIN_BINARY keys show relayer -a --keyring-backend=test --home "$CHAIN_HOME")
    $CHAIN_BINARY add-genesis-account "$VALIDATOR_ADDR" 1000000000000"$DENOM" --home "$CHAIN_HOME"
    $CHAIN_BINARY add-genesis-account "$RELAYER_ADDR" 100000000000"$DENOM" --home "$CHAIN_HOME"

    # 5. gentx (ジェネシストランザクション) を作成
    $CHAIN_BINARY gentx validator 1000000000"$DENOM" \
        --keyring-backend=test \
        --chain-id "$CHAIN_ID" \
        --home "$CHAIN_HOME"

    # 6. gentx を集約
    $CHAIN_BINARY collect-gentxs --home "$CHAIN_HOME"

    # --- 設定ファイルの調整 (変更なし) ---
    CONFIG_TOML="$CHAIN_HOME/config/config.toml"
    APP_TOML="$CHAIN_HOME/config/app.toml"
    sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' "$CONFIG_TOML"
    sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/' "$CONFIG_TOML"
    sed -i '/\[api\]/,/\[/{s/enable = false/enable = true/}' "$APP_TOML"
    sed -i '/\[grpc\]/,/\[/{s/enable = false/enable = true/}' "$APP_TOML"
    sed -i '/\[grpc-web\]/,/\[/{s/enable = false/enable = true/}' "$APP_TOML"

    echo "--- Initialization complete for $CHAIN_ID ---"
fi

# --- ノードの起動 ---
echo "--- Starting node for $CHAIN_ID ---"
exec $CHAIN_BINARY start --home "$CHAIN_HOME"