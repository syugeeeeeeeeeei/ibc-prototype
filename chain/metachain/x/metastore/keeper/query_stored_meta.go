package keeper

import (
	"context"
	"errors"

	"metachain/x/metastore/types"

	"cosmossdk.io/collections"
	"github.com/cosmos/cosmos-sdk/types/query"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func (q queryServer) ListStoredMeta(ctx context.Context, req *types.QueryAllStoredMetaRequest) (*types.QueryAllStoredMetaResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	storedMetas, pageRes, err := query.CollectionPaginate(
		ctx,
		q.k.StoredMeta,
		req.Pagination,
		func(_ string, value types.StoredMeta) (types.StoredMeta, error) {
			return value, nil
		},
	)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	return &types.QueryAllStoredMetaResponse{StoredMeta: storedMetas, Pagination: pageRes}, nil
}

func (q queryServer) GetStoredMeta(ctx context.Context, req *types.QueryGetStoredMetaRequest) (*types.QueryGetStoredMetaResponse, error) {
	if req == nil {
		return nil, status.Error(codes.InvalidArgument, "invalid request")
	}

	val, err := q.k.StoredMeta.Get(ctx, req.Index)
	if err != nil {
		if errors.Is(err, collections.ErrNotFound) {
			return nil, status.Error(codes.NotFound, "not found")
		}

		return nil, status.Error(codes.Internal, "internal error")
	}

	return &types.QueryGetStoredMetaResponse{StoredMeta: val}, nil
}
