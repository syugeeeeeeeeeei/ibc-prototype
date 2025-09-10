#!/bin/sh
set -e

# --- 環境変数と設定 ---
CHAIN_ID=${HOSTNAME}
CHAIN_APP_NAME=${CHAIN_APP_NAME:-datachain}
DENOM="uatom"
USER_HOME="/home/$CHAIN_APP_NAME"
CHAIN_HOME="$USER_HOME/.$CHAIN_APP_NAME"
CHAIN_BINARY="${CHAIN_APP_NAME}d"
MNEMONIC_FILE="/etc/mnemonics/${CHAIN_INSTANCE_NAME}.mnemonic"

# --- 初期化処理 ---
if [ ! -d "$CHAIN_HOME/config" ]; then
    echo "--- Initializing chain: $CHAIN_ID (type: $CHAIN_APP_NAME) ---"

    $CHAIN_BINARY init "$CHAIN_ID" --chain-id "$CHAIN_ID" --home "$CHAIN_HOME"
    sed -i "s/\"stake\"/\"$DENOM\"/g" "$CHAIN_HOME/config/genesis.json"

    VALIDATOR_MNEMONIC=$(cat "$MNEMONIC_FILE")
    
    # ★★★★★★★★★★★★★★★★★★★★★★★★★
    # ★★★ これが最も重要な修正点です ★★★
    # ★★★★★★★★★★★★★★★★★★★★★★★★★
    # --account フラグを追加して、異なるアドレスを派生させる
    echo "$VALIDATOR_MNEMONIC" | $CHAIN_BINARY keys add validator --recover --keyring-backend=test --home "$CHAIN_HOME" --account 0
    echo "$VALIDATOR_MNEMONIC" | $CHAIN_BINARY keys add relayer --recover --keyring-backend=test --home "$CHAIN_HOME" --account 1

    VALIDATOR_ADDR=$($CHAIN_BINARY keys show validator -a --keyring-backend=test --home "$CHAIN_HOME")
    RELAYER_ADDR=$($CHAIN_BINARY keys show relayer -a --keyring-backend=test --home "$CHAIN_HOME")
    $CHAIN_BINARY genesis add-genesis-account "$VALIDATOR_ADDR" 1000000000000"$DENOM" --home "$CHAIN_HOME"
    $CHAIN_BINARY genesis add-genesis-account "$RELAYER_ADDR" 100000000000"$DENOM" --home "$CHAIN_HOME"

    $CHAIN_BINARY genesis gentx validator 1000000000"$DENOM" \
        --keyring-backend=test \
        --chain-id "$CHAIN_ID" \
        --home "$CHAIN_HOME"

    $CHAIN_BINARY genesis collect-gentxs --home "$CHAIN_HOME"

    echo "--- Validating genesis file ---"
    $CHAIN_BINARY genesis validate --home "$CHAIN_HOME"

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
# sleep infinity
exec $CHAIN_BINARY start --home "$CHAIN_HOME" --minimum-gas-prices="0.001$DENOM"