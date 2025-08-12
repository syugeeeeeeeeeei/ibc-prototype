#!/bin/sh
# コマンドが失敗したら即座に終了する
set -e

CONFIG_FILE="/root/.relayer/config/config.yaml"

# リレイヤーの設定ファイルが存在しない場合のみ、初期化処理を実行
if [ ! -f "$CONFIG_FILE" ]; then
    echo "--- Initializing relayer for the first time... ---"

    # 変数定義
    PATH_NAME='my-path'
    CHAIN_ID_1='gaia-1'
    CHAIN_ID_2='gaia-2'

    # 1. リレイヤーの設定を初期化
    rly config init

    # 2. JSONファイルを使ってチェーンを追加
    rly chains add -f /scripts/gaia-1.json gaia-1
    rly chains add -f /scripts/gaia-2.json gaia-2

    # 3. チェーンがリクエストを受け付けるまで待機
    echo "--- Waiting for chains to be ready... ---"
    # rlyの機能でチェーン情報の取得を試み、成功するまで待つ
    until rly chains show "$CHAIN_ID_1" > /dev/null 2>&1; do
        echo "Waiting for gaia-1 to be available..."
        sleep 5
    done
    echo "✅ gaia-1 is ready."

    until rly chains show "$CHAIN_ID_2" > /dev/null 2>&1; do
        echo "Waiting for gaia-2 to be available..."
        sleep 5
    done
    echo "✅ gaia-2 is ready."

    # 4. .envから読み込んだニーモニックを使ってキーをリストア
    rly keys restore "$CHAIN_ID_1" relayer "$RELAYER_MNEMONIC_1"
    rly keys restore "$CHAIN_ID_2" relayer "$RELAYER_MNEMONIC_2"

    # # 5. リレイヤーアカウントの残高が確認できるまで待機
    # echo "--- Waiting for relayer accounts to be funded... ---"
    # until rly query balance "$CHAIN_ID_1"; do
    #     echo "Waiting for gaia-1 relayer account to have a balance..."
    #     sleep 5
    # done
    # echo "✅ gaia-1 relayer account is funded."
    
    # until rly query balance "$CHAIN_ID_2"; do
    #     echo "Waiting for gaia-2 relayer account to have a balance..."
    #     sleep 5
    # done
    # echo "✅ gaia-2 relayer account is funded."

    # 6. 【重要】パスの定義を作成
    echo "--- Creating new IBC path: $PATH_NAME ---"
    rly paths new "$CHAIN_ID_1" "$CHAIN_ID_2" "$PATH_NAME" --src-port transfer --dst-port transfer --order unordered --version ics20-1

    # 7. 【重要】パスのリンク（橋の建設）が成功するまで再試行
    echo "--- Attempting to link path (this can take a moment)... ---"
    ATTEMPTS=0
    MAX_ATTEMPTS=5
    until rly transact link "$PATH_NAME" --debug; do
        ATTEMPTS=$((ATTEMPTS + 1))
        if [ $ATTEMPTS -ge $MAX_ATTEMPTS ]; then
            echo "!!! Failed to link path after $MAX_ATTEMPTS attempts. Check logs. !!!"
            break
        fi
        echo "Link failed. Retrying in 10 seconds... (Attempt $ATTEMPTS/$MAX_ATTEMPTS)"
        sleep 10
    done
fi

# コンテナ起動時に毎回このコマンドが実行される
echo "--- Starting relayer... ---"
exec rly start