package keeper

import (
	"context"
	"errors"
	"fmt"

	"metachain/x/metastore/types"

	"cosmossdk.io/collections"
	errorsmod "cosmossdk.io/errors"
	sdkerrors "github.com/cosmos/cosmos-sdk/types/errors"
)

func (k msgServer) CreateStoredMeta(ctx context.Context, msg *types.MsgCreateStoredMeta) (*types.MsgCreateStoredMetaResponse, error) {
	if _, err := k.addressCodec.StringToBytes(msg.Creator); err != nil {
		return nil, errorsmod.Wrap(sdkerrors.ErrInvalidAddress, fmt.Sprintf("invalid address: %s", err))
	}

	// Check if the value already exists
	ok, err := k.StoredMeta.Has(ctx, msg.Index)
	if err != nil {
		return nil, errorsmod.Wrap(sdkerrors.ErrLogic, err.Error())
	} else if ok {
		return nil, errorsmod.Wrap(sdkerrors.ErrInvalidRequest, "index already set")
	}

	var storedMeta = types.StoredMeta{
		Creator: msg.Creator,
		Index:   msg.Index,
		Url:     msg.Url,
	}

	if err := k.StoredMeta.Set(ctx, storedMeta.Index, storedMeta); err != nil {
		return nil, errorsmod.Wrap(sdkerrors.ErrLogic, err.Error())
	}

	return &types.MsgCreateStoredMetaResponse{}, nil
}

func (k msgServer) UpdateStoredMeta(ctx context.Context, msg *types.MsgUpdateStoredMeta) (*types.MsgUpdateStoredMetaResponse, error) {
	if _, err := k.addressCodec.StringToBytes(msg.Creator); err != nil {
		return nil, errorsmod.Wrap(sdkerrors.ErrInvalidAddress, fmt.Sprintf("invalid signer address: %s", err))
	}

	// Check if the value exists
	val, err := k.StoredMeta.Get(ctx, msg.Index)
	if err != nil {
		if errors.Is(err, collections.ErrNotFound) {
			return nil, errorsmod.Wrap(sdkerrors.ErrKeyNotFound, "index not set")
		}

		return nil, errorsmod.Wrap(sdkerrors.ErrLogic, err.Error())
	}

	// Checks if the msg creator is the same as the current owner
	if msg.Creator != val.Creator {
		return nil, errorsmod.Wrap(sdkerrors.ErrUnauthorized, "incorrect owner")
	}

	var storedMeta = types.StoredMeta{
		Creator: msg.Creator,
		Index:   msg.Index,
		Url:     msg.Url,
	}

	if err := k.StoredMeta.Set(ctx, storedMeta.Index, storedMeta); err != nil {
		return nil, errorsmod.Wrap(sdkerrors.ErrLogic, "failed to update storedMeta")
	}

	return &types.MsgUpdateStoredMetaResponse{}, nil
}

func (k msgServer) DeleteStoredMeta(ctx context.Context, msg *types.MsgDeleteStoredMeta) (*types.MsgDeleteStoredMetaResponse, error) {
	if _, err := k.addressCodec.StringToBytes(msg.Creator); err != nil {
		return nil, errorsmod.Wrap(sdkerrors.ErrInvalidAddress, fmt.Sprintf("invalid signer address: %s", err))
	}

	// Check if the value exists
	val, err := k.StoredMeta.Get(ctx, msg.Index)
	if err != nil {
		if errors.Is(err, collections.ErrNotFound) {
			return nil, errorsmod.Wrap(sdkerrors.ErrKeyNotFound, "index not set")
		}

		return nil, errorsmod.Wrap(sdkerrors.ErrLogic, err.Error())
	}

	// Checks if the msg creator is the same as the current owner
	if msg.Creator != val.Creator {
		return nil, errorsmod.Wrap(sdkerrors.ErrUnauthorized, "incorrect owner")
	}

	if err := k.StoredMeta.Remove(ctx, msg.Index); err != nil {
		return nil, errorsmod.Wrap(sdkerrors.ErrLogic, "failed to remove storedMeta")
	}

	return &types.MsgDeleteStoredMetaResponse{}, nil
}
