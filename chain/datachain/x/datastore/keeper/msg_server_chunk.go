// datachain/x/datastore/keeper/msg_server_chunk.go
package keeper

import (
	"context"
	"fmt"

	"datachain/x/datastore/types"

	errorsmod "cosmossdk.io/errors"
	sdk "github.com/cosmos/cosmos-sdk/types" // ★ sdk パッケージをインポート
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
	clienttypes "github.com/cosmos/ibc-go/v10/modules/core/02-client/types"
)

func (k msgServer) SendChunk(ctx context.Context, msg *types.MsgSendChunk) (*types.MsgSendChunkResponse, error) {
	// validate incoming message (ご提示いただいたオリジナルのバリデーションを維持)
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

	// Construct the packet
	var packet types.ChunkPacketData
	packet.Index = msg.Index
	packet.Data = msg.Data

	sdkCtx := sdk.UnwrapSDKContext(ctx)

	// ★★★ ここが最重要修正点 ★★★
	// Transmit the packet by calling the method on the embedded Keeper
	_, err := k.Keeper.TransmitChunkPacket(
		sdkCtx, // context を sdk.Context に変更
		packet,
		msg.Port,
		msg.ChannelID,
		clienttypes.ZeroHeight(),
		msg.TimeoutTimestamp,
	)
	if err != nil {
		return nil, err
	}

	return &types.MsgSendChunkResponse{}, nil
}
