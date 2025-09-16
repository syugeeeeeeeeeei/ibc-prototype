package keeper

import (
	"context"
	"errors"

	"metachain/x/metastore/types"

	"cosmossdk.io/collections"
)

// InitGenesis initializes the module's state from a provided genesis state.
func (k Keeper) InitGenesis(ctx context.Context, genState types.GenesisState) error {
	if err := k.Port.Set(ctx, genState.PortId); err != nil {
		return err
	}
	for _, elem := range genState.StoredMetaMap {
		if err := k.StoredMeta.Set(ctx, elem.Index, elem); err != nil {
			return err
		}
	}

	return k.Params.Set(ctx, genState.Params)
}

// ExportGenesis returns the module's exported genesis.
func (k Keeper) ExportGenesis(ctx context.Context) (*types.GenesisState, error) {
	var err error

	genesis := types.DefaultGenesis()
	genesis.Params, err = k.Params.Get(ctx)
	if err != nil {
		return nil, err
	}
	genesis.PortId, err = k.Port.Get(ctx)
	if err != nil && !errors.Is(err, collections.ErrNotFound) {
		return nil, err
	}
	if err := k.StoredMeta.Walk(ctx, nil, func(_ string, val types.StoredMeta) (stop bool, err error) {
		genesis.StoredMetaMap = append(genesis.StoredMetaMap, val)
		return false, nil
	}); err != nil {
		return nil, err
	}

	return genesis, nil
}
