// x/datastore/keeper/chunk.go
package keeper

import (
	"context"
	"fmt"
	"strings"

	"datachain/x/datastore/types"

	errorsmod "cosmossdk.io/errors"
	sdk "github.com/cosmos/cosmos-sdk/types"
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
	clienttypes "github.com/cosmos/ibc-go/v10/modules/core/02-client/types"
	channeltypes "github.com/cosmos/ibc-go/v10/modules/core/04-channel/types"
)

// OnRecvChunkPacket is called when the datachain receives a packet from metachain.
// This function implements the core business logic for the datastore module.
func (k Keeper) OnRecvChunkPacket(ctx context.Context, packet channeltypes.Packet, data types.ChunkPacketData) (*types.ChunkPacketAck, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	fmt.Printf("datachain [DEBUG]: OnRecvChunkPacket received packet with index/addresses: %s\n", data.Index)

	// --- ★★★ ここからが実装されたビジネスロジックです ★★★ ---
	// Logic:
	// 1. The 'Index' field from the packet actually contains a comma-separated list of data addresses.
	// 2. We parse this list.
	// 3. For each address, we check if the corresponding data chunk exists in our state.
	// 4. If ANY of the chunks do not exist, we return a specific error acknowledgement.
	// 5. If ALL chunks exist, we return a successful acknowledgement.

	addresses := strings.Split(data.Index, ",")
	if len(addresses) == 0 {
		return nil, errorsmod.Wrap(sdkerrors.ErrInvalidRequest, "addresses list in packet index cannot be empty")
	}

	for _, addr := range addresses {
		found, err := k.StoredChunk.Has(sdkCtx, addr)
		if err != nil {
			// This indicates an internal store/database error.
			return nil, errorsmod.Wrapf(err, "error checking for chunk with index %s", addr)
		}
		if !found {
			// If a chunk is not found, immediately return a custom error.
			// This error will be sent back to the metachain.
			fmt.Printf("datachain [ERROR]: Chunk with index '%s' not found.\n", addr)
			return nil, errorsmod.Wrapf(types.ErrChunkNotFound, "chunk with index %s not found", addr)
		}
		fmt.Printf("datachain [SUCCESS]: Verified chunk with index '%s' exists.\n", addr)
	}

	// If the loop completes without errors, it means all chunks were found.
	// We return a successful (but empty) acknowledgement.
	// --- ★★★ ロジックここまで ★★★ ---

	return &types.ChunkPacketAck{}, nil
}

// TransmitChunkPacket transmits the packet over IBC with the specified source port and source channel
func (k Keeper) TransmitChunkPacket(
	ctx context.Context,
	packetData types.ChunkPacketData,
	sourcePort,
	sourceChannel string,
	timeoutHeight clienttypes.Height,
	timeoutTimestamp uint64,
) (uint64, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	packetBytes, err := packetData.GetBytes()
	if err != nil {
		return 0, errorsmod.Wrapf(sdkerrors.ErrJSONMarshal, "cannot marshal the packet: %s", err)
	}

	return k.ibcKeeperFn().ChannelKeeper.SendPacket(sdkCtx, sourcePort, sourceChannel, timeoutHeight, timeoutTimestamp, packetBytes)
}

// OnAcknowledgementChunkPacket is called when datachain receives an acknowledgement for a packet it sent.
func (k Keeper) OnAcknowledgementChunkPacket(ctx context.Context, packet channeltypes.Packet, data types.ChunkPacketData, ack channeltypes.Acknowledgement) error {
	// This module is designed to only receive packets, not send them,
	// so this function should ideally not be triggered.
	return nil
}

// OnTimeoutChunkPacket is called when a packet sent from datachain times out.
func (k Keeper) OnTimeoutChunkPacket(ctx context.Context, packet channeltypes.Packet, data types.ChunkPacketData) error {
	// This module is designed to only receive packets, not send them,
	// so this function should ideally not be triggered.
	return nil
}
