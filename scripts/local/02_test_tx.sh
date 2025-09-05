#!/bin/bash
set -euo pipefail

# 共通の環境変数を読み込みます
source "$(dirname "$0")/../env.sh"

CHAIN_BINARY_PATH="$(go env GOPATH)/bin/${APP_NAME}d"

# --- Helper Functions ---
check_binary() {
    if ! [ -x "${CHAIN_BINARY_PATH}" ]; then
        echo "Error: Chain binary not found or not executable at ${CHAIN_BINARY_PATH}"
        echo "Please run 'make start-datachain' at least once to build the binary."
        exit 1
    fi
}

wait_for_block() {
    echo "--> 🕒 Waiting $1s for transaction to be committed..."
    sleep "$1"
}

# --- Main Script ---
check_binary

echo "--> 🧪 Starting transaction test sequence..."

# 1. 前回のテストデータが残っている可能性を考慮して、最初に削除を試みる
echo -e "\n--> 🧹 [CLEANUP] Deleting chunk with Index: ${TEST_INDEX} (if exists)"
"${CHAIN_BINARY_PATH}" tx "${MODULE_NAME}" delete-chunk "${TEST_INDEX}" \
    --from "${TEST_ACCOUNT}" --chain-id "${CHAIN_ID}" --gas auto --gas-adjustment 1.5 -y || true
wait_for_block 3

# 2. データの作成 (Create)
echo -e "\n--> 📤 [CREATE] Creating chunk with Index: ${TEST_INDEX}"
"${CHAIN_BINARY_PATH}" tx "${MODULE_NAME}" create-chunk "${TEST_INDEX}" "$(echo -n "${TEST_DATA_1}" | base64 -w 0)" \
    --from "${TEST_ACCOUNT}" --chain-id "${CHAIN_ID}" --gas auto --gas-adjustment 1.5 -y
wait_for_block 3

# 3. データの確認 (Show)
echo -e "\n--> 🔎 [SHOW] Querying chunk with Index: ${TEST_INDEX}"
"${CHAIN_BINARY_PATH}" query "${MODULE_NAME}" show-chunk "${TEST_INDEX}"
wait_for_block 1

# 4. データの更新 (Update)
echo -e "\n--> 🔄 [UPDATE] Updating chunk with Index: ${TEST_INDEX}"
"${CHAIN_BINARY_PATH}" tx "${MODULE_NAME}" update-chunk "${TEST_INDEX}" "$(echo -n "${TEST_DATA_2}" | base64 -w 0)" \
    --from "${TEST_ACCOUNT}" --chain-id "${CHAIN_ID}" --gas auto --gas-adjustment 1.5 -y
wait_for_block 3

# 5. 更新後のデータを確認 (Show)
echo -e "\n--> 🔎 [SHOW] Verifying updated chunk with Index: ${TEST_INDEX}"
"${CHAIN_BINARY_PATH}" query "${MODULE_NAME}" show-chunk "${TEST_INDEX}"
wait_for_block 1

# 6. データの削除 (Delete)
echo -e "\n--> 🗑️   [DELETE] Deleting chunk with Index: ${TEST_INDEX}"
"${CHAIN_BINARY_PATH}" tx "${MODULE_NAME}" delete-chunk "${TEST_INDEX}" \
    --from "${TEST_ACCOUNT}" --chain-id "${CHAIN_ID}" --gas auto --gas-adjustment 1.5 -y
wait_for_block 3

# 7. 削除されたことを確認 (Show Fail)
echo -e "\n--> ❌ [SHOW FAIL] Verifying chunk is deleted..."
if ! "${CHAIN_BINARY_PATH}" query "${MODULE_NAME}" show-chunk "${TEST_INDEX}" >/dev/null 2>&1; then
    echo "✅ Chunk correctly not found."
else
    echo "❌ Error: Chunk still exists after deletion."
    exit 1
fi

echo -e "\n🎉 All transaction tests passed successfully!"