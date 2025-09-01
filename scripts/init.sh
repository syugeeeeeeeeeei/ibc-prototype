#!/bin/sh
set -e

CHAIN_ID=$(hostname)
NODE_DATA_PATH="/data"
USER="validator"
RELAYER_KEY="relayer"
# Secretから取得したニーモニックを使用
MNEMONIC_VAR_NAME="MNEMONIC_$(echo $CHAIN_ID | cut -d'-' -f2)"
RELAYER_MNEMONIC_VAR_NAME="RELAYER_MNEMONIC_$(echo $CHAIN_ID | cut -d'-' -f2)"

if [ ! -f "$NODE_DATA_PATH/config/genesis.json" ]; then
  echo "--- Initializing $CHAIN_ID ---"
  gaiad init test --chain-id "$CHAIN_ID" --home "$NODE_DATA_PATH"

  sed -i 's/"stake"/"uatom"/g' "$NODE_DATA_PATH/config/genesis.json"
  sed -i 's/127.0.0.1/0.0.0.0/g' "$NODE_DATA_PATH/config/config.toml"
  sed -i 's/enable = false/enable = true/g' "$NODE_DATA_PATH/config/app.toml"
  sed -i 's/minimum-gas-prices = ""/minimum-gas-prices = "1uatom"/g' "$NODE_DATA_PATH/config/app.toml"

  echo "${!MNEMONIC_VAR_NAME}" | gaiad keys add $USER --home "$NODE_DATA_PATH" --keyring-backend=test --recover
  echo "${!RELAYER_MNEMONIC_VAR_NAME}" | gaiad keys add $RELAYER_KEY --home "$NODE_DATA_PATH" --keyring-backend=test --recover

  gaiad genesis add-genesis-account "$(gaiad keys show $USER -a --home "$NODE_DATA_PATH" --keyring-backend=test)" 1000000000000uatom --home "$NODE_DATA_PATH"
  gaiad genesis add-genesis-account "$(gaiad keys show $RELAYER_KEY -a --home "$NODE_DATA_PATH" --keyring-backend=test)" 1000000000000uatom --home "$NODE_DATA_PATH"

  # ★★★ 修正点: gentxの委任額をDefaultPowerReduction以上になるように増やす ★★★
  gaiad genesis gentx $USER 1000000000000uatom --chain-id "$CHAIN_ID" --home "$NODE_DATA_PATH" --keyring-backend=test
  gaiad genesis collect-gentxs --home "$NODE_DATA_PATH"
fi

echo "--- Initialization of $CHAIN_ID complete! ---"