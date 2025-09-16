package types

import (
	"fmt"

	host "github.com/cosmos/ibc-go/v10/modules/core/24-host"
)

// DefaultGenesis returns the default genesis state
func DefaultGenesis() *GenesisState {
	return &GenesisState{
		Params: DefaultParams(),
		PortId: PortID, StoredMetaMap: []StoredMeta{}}
}

// Validate performs basic genesis state validation returning an error upon any
// failure.
func (gs GenesisState) Validate() error {
	if err := host.PortIdentifierValidator(gs.PortId); err != nil {
		return err
	}
	storedMetaIndexMap := make(map[string]struct{})

	for _, elem := range gs.StoredMetaMap {
		index := fmt.Sprint(elem.Index)
		if _, ok := storedMetaIndexMap[index]; ok {
			return fmt.Errorf("duplicated index for storedMeta")
		}
		storedMetaIndexMap[index] = struct{}{}
	}

	return gs.Params.Validate()
}
