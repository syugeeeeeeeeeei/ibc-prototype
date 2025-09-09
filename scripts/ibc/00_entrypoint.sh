#!/bin/bash
set -e # エラーが発生した時点でスクリプトを終了する

# --- 環境変数と引数の設定 ---
CHAIN_ID=${1:-"metadata-chain"}
DENOM=${2:-"uatom"}
# コンテナ内のユーザーホーム。Dockerfileで作成したユーザーに合わせる
USER_HOME="/home/datachain"
CHAIN_HOME="$USER_HOME/.datachain"
CHAIN_BINARY="datachaind"

# --- 初期化処理 ---
# データディレクトリが存在しない場合のみ初期化処理を実行
if [ ! -d "$CHAIN_HOME/config" ]; then
    echo "--- Initializing chain: $CHAIN_ID ---"

    # 1. チェーンの初期化
    $CHAIN_BINARY init "$CHAIN_ID" --chain-id "$CHAIN_ID" --home "$CHAIN_HOME"

    # 2. デフォルトのdenomを 'stake' から指定されたものに変更
    sed -i "s/\"stake\"/\"$DENOM\"/g" "$CHAIN_HOME/config/genesis.json"

    # 3. バリデータ用のキーを作成
    $CHAIN_BINARY keys add validator --keyring-backend=test --home "$CHAIN_HOME"

    # 4. ジェネシスアカウントを追加（十分な資金を持つ）
    $CHAIN_BINARY add-genesis-account \
        $( $CHAIN_BINARY keys show validator -a --keyring-backend=test --home "$CHAIN_HOME" ) \
        1000000000000"$DENOM" \
        --home "$CHAIN_HOME"

    # 5. リレイヤー用のキーを作成し、ジェネシスアカウントとして追加
    $CHAIN_BINARY keys add relayer --keyring-backend=test --home "$CHAIN_HOME"
    $CHAIN_BINARY add-genesis-account \
        $( $CHAIN_BINARY keys show relayer -a --keyring-backend=test --home "$CHAIN_HOME" ) \
        100000000000"$DENOM" \
        --home "$CHAIN_HOME"

    # 6. gentx (ジェネシストランザクション) を作成
    $CHAIN_BINARY gentx validator 1000000000"$DENOM" \
        --keyring-backend=test \
        --chain-id "$CHAIN_ID" \
        --home "$CHAIN_HOME"

    # 7. gentx を集約
    $CHAIN_BINARY collect-gentxs --home "$CHAIN_HOME"

    # --- 設定ファイルの調整 ---
    CONFIG_TOML="$CHAIN_HOME/config/config.toml"
    APP_TOML="$CHAIN_HOME/config/app.toml"

    # CORSを許可してブラウザからのアクセスを可能にする
    sed -i 's/laddr = "tcp:\/\/127.0.0.1:26657"/laddr = "tcp:\/\/0.0.0.0:26657"/' "$CONFIG_TOML"
    sed -i 's/cors_allowed_origins = \[\]/cors_allowed_origins = \["\*"\]/' "$CONFIG_TOML"

    # APIサーバーとgRPCを有効にする
    sed -i '/\[api\]/,/\[/{s/enable = false/enable = true/}' "$APP_TOML"
    sed -i '/\[grpc\]/,/\[/{s/enable = false/enable = true/}' "$APP_TOML"
    sed -i '/\[grpc-web\]/,/\[/{s/enable = false/enable = true/}' "$APP_TOML"

    echo "--- Initialization complete for $CHAIN_ID ---"
fi

# --- ノードの起動 ---
echo "--- Starting node for $CHAIN_ID ---"
exec $CHAIN_BINARY start --home "$CHAIN_HOME"