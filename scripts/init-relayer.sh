#!/bin/sh
set -e

CONFIG_FILE="/root/.relayer/config/config.yaml"
PATH_NAME='my-path'
NUM_CHAINS=${NUM_CHAINS:-2}

if [ ! -f "$CONFIG_FILE" ]; then
    echo "--- Initializing relayer for the first time... ---"
    rly config init

    echo "--- Adding chains to relayer config ---"
    for i in $(seq 0 $((NUM_CHAINS-1))); do
        CHAIN_ID="gaia-$i"
        rly chains add "$CHAIN_ID" --json '{"type": "cosmos", "value": {"key": "relayer", "chain-id": "'"$CHAIN_ID"'", "rpc-addr": "http://gaia-service:26657", "grpc-addr": "gaia-service:9090", "account-prefix": "cosmos", "keyring-backend": "test", "gas-adjustment": 5, "gas-prices": "1uatom", "trusting-period": "336h", "timeout": "20s"}}'
    done

    echo "--- Waiting for chains to be ready... ---"
    for i in $(seq 0 $((NUM_CHAINS-1))); do
        CHAIN_ID="gaia-$i"
        until rly chains show "$CHAIN_ID" > /dev/null 2>&1; do
            echo "Waiting for $CHAIN_ID to be available..."
            sleep 5
        done
        echo "✅ $CHAIN_ID is ready."
    done

    for i in $(seq 0 $((NUM_CHAINS-1))); do
        CHAIN_ID="gaia-$i"
        RELAYER_MNEMONIC_VAR_NAME="RELAYER_MNEMONIC_$i"
        RELAYER_MNEMONIC=$(eval "echo \$$RELAYER_MNEMONIC_VAR_NAME")
        rly keys restore "$CHAIN_ID" relayer "$RELAYER_MNEMONIC"
    done

    echo "--- Creating new IBC path: $PATH_NAME ---"
    rly paths new "gaia-0" "gaia-1" "$PATH_NAME" --src-port transfer --dst-port transfer --order unordered --version ics20-1

    echo "--- Attempting to link path... ---"
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

echo "--- Starting relayer... ---"
exec rly start