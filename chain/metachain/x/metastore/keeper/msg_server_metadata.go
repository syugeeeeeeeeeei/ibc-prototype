package keeper

import (
	"context"
	"fmt"

	"metachain/x/metastore/types"

	errorsmod "cosmossdk.io/errors"
	sdk "github.com/cosmos/cosmos-sdk/types"
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
	clienttypes "github.com/cosmos/ibc-go/v10/modules/core/02-client/types"
)

func (k msgServer) SendMetadata(ctx context.Context, msg *types.MsgSendMetadata) (*types.MsgSendMetadataResponse, error) {
	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// validate incoming message (バリデーションはIgniteが自動生成したものを維持)
	if _, err := k.addressCodec.StringToBytes(msg.Creator); err != nil {
		return nil, errorsmod.Wrap(sdkerrors.ErrInvalidAddress, fmt.Sprintf("invalid address: %s", err))
	}
	if msg.Port == "" {
		return nil, errorsmod.Wrap(sdkerrors.ErrInvalidRequest, "invalid packet port")
	}
	if msg.ChannelID == "" {
		return nil, errorsmod.Wrap(sdkerrors.ErrInvalidRequest, "invalid packet channel")
	}
	if msg.TimeoutTimestamp == 0 {
		return nil, errorsmod.Wrap(sdkerrors.ErrInvalidRequest, "invalid packet timeout")
	}

	// ★★★ ここからが修正箇所です ★★★

	// Construct the packet with the Creator field
	var packet = types.MetadataPacketData{
		Url:       msg.Url,
		Addresses: msg.Addresses,
		Creator:   msg.Creator, // トランザクションの実行者(Creator)の情報をパケットに含める
	}

	// Transmit the packet
	_, err := k.TransmitMetadataPacket(
		sdkCtx, // Use sdkCtx instead of ctx
		packet,
		msg.Port,
		msg.ChannelID,
		clienttypes.ZeroHeight(),
		msg.TimeoutTimestamp,
	)
	if err != nil {
		return nil, err
	}

	return &types.MsgSendMetadataResponse{}, nil
}
