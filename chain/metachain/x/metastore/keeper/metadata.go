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

// OnRecvMetadataPacket processes packet reception
func (k Keeper) OnRecvMetadataPacket(ctx context.Context, packet channeltypes.Packet, data types.MetadataPacketData) (packetAck types.MetadataPacketAck, err error) {
	// This chain is meant to send, not receive this packet type.
	// Nevertheless, we can add logic here if needed in the future.
	return packetAck, nil
}

// OnAcknowledgementMetadataPacket responds to the success or failure of a packet
// acknowledgement written on the receiving chain.
func (k Keeper) OnAcknowledgementMetadataPacket(ctx context.Context, packet channeltypes.Packet, data types.MetadataPacketData, ack channeltypes.Acknowledgement) error {
	sdkCtx := sdk.UnwrapSDKContext(ctx)
	fmt.Printf("metachain [DEBUG]: OnAcknowledgementPacket received ack: %v\n", ack)

	switch dispatchedAck := ack.Response.(type) {
	case *channeltypes.Acknowledgement_Error:
		fmt.Printf("metachain [DEBUG]: Acknowledgement is an ERROR: %s\n", dispatchedAck.Error)
		return nil

	case *channeltypes.Acknowledgement_Result:
		fmt.Println("metachain [DEBUG]: Acknowledgement is a SUCCESS.")

		// Decode the packet acknowledgment (datachainからの応答は空で良いので、ここでは特に使わない)
		var packetAck types.MetadataPacketAck
		if err := k.cdc.UnmarshalJSON(dispatchedAck.Result, &packetAck); err != nil {
			fmt.Printf("metachain [ERROR]: cannot unmarshal acknowledgment: %s\n", err.Error())
			return errors.New("cannot unmarshal acknowledgment")
		}

		// ★★★ ここが最終的な実装です ★★★
		fmt.Println("metachain [DEBUG]: Storing metadata...")
		storedMeta := types.StoredMeta{
			Index:   data.Url, // StoredMetaのキーとなるIndexフィールドにURLを設定
			Url:     data.Url,
			Creator: data.Creator, // ステップ2でパケットに含めたCreator情報を使用
		}

		// `k.SetStoredMeta`が未定義であるというエラーについて:
		// `ignite scaffold map stored-meta ...` コマンドは、
		// `x/metastore/keeper/stored_meta.go` というファイルに
		// `SetStoredMeta`関数を自動生成するはずです。
		// もしこの関数が存在しない場合、scaffoldコマンドが正しく実行されなかった可能性があります。
		k.SetStoredMeta(sdkCtx, storedMeta)

		fmt.Printf("metachain [SUCCESS]: Stored metadata for URL: %s\n", data.Url)

		return nil
	default:
		return errors.New("invalid acknowledgment format")
	}
}

// OnTimeoutMetadataPacket responds to the case where a packet has not been transmitted because of a timeout
func (k Keeper) OnTimeoutMetadataPacket(ctx context.Context, packet channeltypes.Packet, data types.MetadataPacketData) error {
	// TODO: packet timeout logic
	return nil
}
