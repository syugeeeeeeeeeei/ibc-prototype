#!/bin/sh
set -e

# --- 変数定義（環境変数から読み込む） ---
CHAIN_ID_1='gaia-1'
USER_1='validator'
RELAYER_KEY_1='relayer'

CHAIN_ID_2='gaia-2'
USER_2='validator'
RELAYER_KEY_2='relayer'

# --- gaia-1 の初期化 ---
if [ ! -f /data/gaia-1/config/genesis.json ]; then
  echo "--- Initializing gaia-1 ---"
  gaiad init test --chain-id $CHAIN_ID_1 --home /data/gaia-1

  sed -i 's/"stake"/"uatom"/g' /data/gaia-1/config/genesis.json
  sed -i 's/127.0.0.1/0.0.0.0/g' /data/gaia-1/config/config.toml
  sed -i 's/enable = false/enable = true/g' /data/gaia-1/config/app.toml
  # ★★★ 修正点： 最低ガス価格をリレイヤーの設定(0.01uatom)と合わせる ★★★
  sed -i 's/minimum-gas-prices = ""/minimum-gas-prices = "1uatom"/g' /data/gaia-1/config/app.toml

  echo "$MNEMONIC_1" | gaiad keys add $USER_1 --home /data/gaia-1 --keyring-backend=test --recover
  echo "$RELAYER_MNEMONIC_1" | gaiad keys add $RELAYER_KEY_1 --home /data/gaia-1 --keyring-backend=test --recover

  gaiad genesis add-genesis-account $(gaiad keys show $USER_1 -a --home /data/gaia-1 --keyring-backend=test) 10000000000uatom --home /data/gaia-1
  gaiad genesis add-genesis-account $(gaiad keys show $RELAYER_KEY_1 -a --home /data/gaia-1 --keyring-backend=test) 10000000000uatom --home /data/gaia-1

  gaiad genesis gentx $USER_1 1000000uatom --chain-id $CHAIN_ID_1 --home /data/gaia-1 --keyring-backend=test
  gaiad genesis collect-gentxs --home /data/gaia-1
fi

# --- gaia-2 の初期化 ---
if [ ! -f /data/gaia-2/config/genesis.json ]; then
  echo "--- Initializing gaia-2 ---"
  gaiad init test --chain-id $CHAIN_ID_2 --home /data/gaia-2

  sed -i 's/"stake"/"uatom"/g' /data/gaia-2/config/genesis.json
  sed -i 's/127.0.0.1/0.0.0.0/g' /data/gaia-2/config/config.toml
  sed -i 's/enable = false/enable = true/g' /data/gaia-2/config/app.toml
  # ★★★ 修正点： 最低ガス価格をリレイヤーの設定(0.01uatom)と合わせる ★★★
  sed -i 's/minimum-gas-prices = ""/minimum-gas-prices = "1uatom"/g' /data/gaia-2/config/app.toml
  
  echo "$MNEMONIC_2" | gaiad keys add $USER_2 --home /data/gaia-2 --keyring-backend=test --recover
  echo "$RELAYER_MNEMONIC_2" | gaiad keys add $RELAYER_KEY_2 --home /data/gaia-2 --keyring-backend=test --recover

  gaiad genesis add-genesis-account $(gaiad keys show $USER_2 -a --home /data/gaia-2 --keyring-backend=test) 10000000000uatom --home /data/gaia-2
  gaiad genesis add-genesis-account $(gaiad keys show $RELAYER_KEY_2 -a --home /data/gaia-2 --keyring-backend=test) 10000000000uatom --home /data/gaia-2

  gaiad genesis gentx $USER_2 1000000uatom --chain-id $CHAIN_ID_2 --home /data/gaia-2 --keyring-backend=test
  gaiad genesis collect-gentxs --home /data/gaia-2
fi

echo "--- All chains initialized successfully! ---"