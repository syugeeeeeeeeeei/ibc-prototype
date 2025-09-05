#!/bin/bash

# ====================================================================================
# Shared Environment Variables
# ====================================================================================
# このファイルは他のスクリプトから 'source' されることを想定しています。

export APP_NAME="datachain"
# 注意: モジュール名はスキャフォールド時に指定した単数形の 'datastore' です
export MODULE_NAME="datastore"
export SIGNER_NAME="creator"

export CHAIN_ID="datachain"
export TEST_ACCOUNT="alice"

# トランザクションテスト用の変数
export TEST_INDEX="my-first-cid"
export TEST_DATA_1="hello cosmos"
export TEST_DATA_2="hello updated"