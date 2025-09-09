#!/bin/sh
set -e

# --- 環境変数 ---
RELAYER_HOME="/home/relayer/.relayer"
CHAIN1_ID="metadata-chain"
CHAIN2_ID="data-chain-1"
CHAIN1_RPC="http://metadata-chain:26657"
CHAIN2_RPC="http://data-chain-1:26657"
CHAIN1_GRPC="metadata-chain:9090"
CHAIN2_GRPC="data-chain-1:9090"
KEY_NAME="relayer"
DENOM="uatom"
PATH_NAME="transfer-path"

# --- リレイヤーの初期化 ---
echo "--- Initializing relayer configuration ---"
# 設定ファイルが存在しない場合のみ初期化
if [ ! -f "$RELAYER_HOME/config/config.yaml" ]; then
    rly config init
fi

# --- チェーン情報の追加 ---
echo "--- Adding chain configurations ---"
# sedでデフォルトの設定を書き換えてから、チェーン情報を追加
sed -i 's/timeout: 10s/timeout: 30s/' "$RELAYER_HOME/config/config.yaml"
sed -i 's/memo: ""/memo: "relayed by docker"/' "$RELAYER_HOME/config/config.yaml"

rly chains add \
    --file - \
    "$CHAIN1_ID" <<EOF
{
  "type": "cosmos",
  "value": {
    "key": "$KEY_NAME",
    "chain-id": "$CHAIN1_ID",
    "rpc-addr": "$CHAIN1_RPC",
    "grpc-addr": "$CHAIN1_GRPC",
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

rly chains add \
    --file - \
    "$CHAIN2_ID" <<EOF
{
  "type": "cosmos",
  "value": {
    "key": "$KEY_NAME",
    "chain-id": "$CHAIN2_ID",
    "rpc-addr": "$CHAIN2_RPC",
    "grpc-addr": "$CHAIN2_GRPC",
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


# --- ニーモニックからキーをリストア ---
# 各チェーンの`00_entrypoint.sh`で'relayer'という名前で作成したキーのニーモニックを取得
# 注意: ここではコンテナ内から`datachaind`コマンドを実行できないため、
# 本来はSecret等でニーモニックを安全に渡す必要があります。
# プロトタイプのため、ここでは既知のテスト用ニーモニックを使用します。
# (Cosmos SDKの標準的なテストニーモニック)
RELAYER_MNEMONIC="figure web rescue rice quantum sustain alert citizen woman laundry assume duty"

echo "--- Restoring relayer keys ---"
rly keys restore "$CHAIN1_ID" "$KEY_NAME" "$RELAYER_MNEMONIC"
rly keys restore "$CHAIN2_ID" "$KEY_NAME" "$RELAYER_MNEMONIC"


# --- IBC接続の確立 ---
echo "--- Waiting for chains to be ready... ---"
sleep 10 # healthcheckがあるため本来不要だが、念のため待機

echo "--- Creating IBC path: $PATH_NAME ---"
rly paths new "$CHAIN1_ID" "$CHAIN2_ID" "$PATH_NAME" \
    --src-port transfer --dst-port transfer \
    --order unordered --version ics20-1

echo "--- Linking the path (clients, connection, channel) ---"
# 資金が反映されるまで数秒待つ
sleep 5
rly transact link "$PATH_NAME" --debug

# --- リレイヤーの起動 ---
echo "--- Starting relayer ---"
exec rly start "$PATH_NAME" --debug