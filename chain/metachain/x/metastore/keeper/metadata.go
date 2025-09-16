// chain/metachain/x/metastore/keeper/metadata_packet.go

package keeper

import (
	"context"
	"errors"
	"fmt"

	"metachain/x/metastore/types"

	errorsmod "cosmossdk.io/errors"
	sdk "github.com/cosmos/cosmos-sdk/types"
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
	clienttypes "github.com/cosmos/ibc-go/v10/modules/core/02-client/types"
	channeltypes "github.com/cosmos/ibc-go/v10/modules/core/04-channel/types"
)

// TransmitMetadataPacket transmits the packet over IBC with the specified source port and source channel
func (k Keeper) TransmitMetadataPacket(
	ctx context.Context,
	packetData types.MetadataPacketData,
	sourcePort,
	sourceChannel string,
	timeoutHeight clienttypes.Height,
	timeoutTimestamp uint64,
) (uint64, error) {
	packetBytes, err := packetData.GetBytes()
	if err != nil {
		return 0, errorsmod.Wrapf(sdkerrors.ErrJSONMarshal, "cannot marshal the packet: %s", err)
	}

	sdkCtx := sdk.UnwrapSDKContext(ctx)
	return k.ibcKeeperFn().ChannelKeeper.SendPacket(sdkCtx, sourcePort, sourceChannel, timeoutHeight, timeoutTimestamp, packetBytes)
}

// OnRecvMetadataPacket is called when the metachain receives a packet of this type.
// This chain is designed to send, not receive, these packets, so this function should ideally not be called.
func (k Keeper) OnRecvMetadataPacket(ctx context.Context, packet channeltypes.Packet, data types.MetadataPacketData) (packetAck types.MetadataPacketAck, err error) {
	// This module is not meant to receive this packet type, return an error.
	return packetAck, errors.New("metastore module is not supposed to receive metadata packets")
}

// OnAcknowledgementMetadataPacket responds to the success or failure of a packet acknowledgement.
func (k Keeper) OnAcknowledgementMetadataPacket(ctx context.Context, packet channeltypes.Packet, data types.MetadataPacketData, ack channeltypes.Acknowledgement) error {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	fmt.Printf("metachain [DEBUG]: OnAcknowledgementPacket received ack: %v\n", ack)

	switch dispatchedAck := ack.Response.(type) {
	case *channeltypes.Acknowledgement_Error:
		fmt.Printf("metachain [DEBUG]: Acknowledgement is an ERROR: %s\n", dispatchedAck.Error)
		return nil

	case *channeltypes.Acknowledgement_Result:
		fmt.Println("metachain [DEBUG]: Acknowledgement is a SUCCESS.")

		// Decode the packet acknowledgment from datachain
		var packetAck types.MetadataPacketAck
		if err := k.cdc.UnmarshalJSON(dispatchedAck.Result, &packetAck); err != nil {
			fmt.Printf("metachain [ERROR]: cannot unmarshal acknowledgment: %s\n", err.Error())
			return errors.New("cannot unmarshal acknowledgment")
		}

		// --- ★★★ ここが最重要修正点 ★★★ ---
		// The core logic: if the acknowledgement is successful, store the metadata.
		fmt.Println("metachain [DEBUG]: Storing metadata...")
		storedMeta := types.StoredMeta{
			Index:   data.Url, // Use the URL as the primary key/index for the stored data.
			Url:     data.Url,
			Creator: data.Creator, // Use the Creator from the original packet data.
		}

		// Use the StoredMeta field from the keeper to call the Set method.
		if err := k.StoredMeta.Set(sdkCtx, storedMeta.Index, storedMeta); err != nil {
			return err
		}

		fmt.Printf("metachain [SUCCESS]: Stored metadata for URL: %s\n", data.Url)
		// --- ★★★ 修正ここまで ★★★ ---

		return nil
	default:
		return errors.New("invalid acknowledgment format")
	}
}

// OnTimeoutMetadataPacket responds to a packet timeout.
func (k Keeper) OnTimeoutMetadataPacket(ctx context.Context, packet channeltypes.Packet, data types.MetadataPacketData) error {
	// TODO: logic for packet timeout
	return nil
}
