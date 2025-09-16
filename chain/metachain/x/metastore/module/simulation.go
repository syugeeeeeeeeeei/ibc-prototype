package metastore

import (
	"math/rand"

	"github.com/cosmos/cosmos-sdk/types/module"
	simtypes "github.com/cosmos/cosmos-sdk/types/simulation"
	"github.com/cosmos/cosmos-sdk/x/simulation"

	"metachain/testutil/sample"
	metastoresimulation "metachain/x/metastore/simulation"
	"metachain/x/metastore/types"
)

// GenerateGenesisState creates a randomized GenState of the module.
func (AppModule) GenerateGenesisState(simState *module.SimulationState) {
	accs := make([]string, len(simState.Accounts))
	for i, acc := range simState.Accounts {
		accs[i] = acc.Address.String()
	}
	metastoreGenesis := types.GenesisState{
		Params: types.DefaultParams(),
		PortId: types.PortID,
		StoredMetaMap: []types.StoredMeta{{Creator: sample.AccAddress(),
			Index: "0",
		}, {Creator: sample.AccAddress(),
			Index: "1",
		}}}
	simState.GenState[types.ModuleName] = simState.Cdc.MustMarshalJSON(&metastoreGenesis)
}

// RegisterStoreDecoder registers a decoder.
func (am AppModule) RegisterStoreDecoder(_ simtypes.StoreDecoderRegistry) {}

// WeightedOperations returns the all the gov module operations with their respective weights.
func (am AppModule) WeightedOperations(simState module.SimulationState) []simtypes.WeightedOperation {
	operations := make([]simtypes.WeightedOperation, 0)
	const (
		opWeightMsgCreateStoredMeta          = "op_weight_msg_metastore"
		defaultWeightMsgCreateStoredMeta int = 100
	)

	var weightMsgCreateStoredMeta int
	simState.AppParams.GetOrGenerate(opWeightMsgCreateStoredMeta, &weightMsgCreateStoredMeta, nil,
		func(_ *rand.Rand) {
			weightMsgCreateStoredMeta = defaultWeightMsgCreateStoredMeta
		},
	)
	operations = append(operations, simulation.NewWeightedOperation(
		weightMsgCreateStoredMeta,
		metastoresimulation.SimulateMsgCreateStoredMeta(am.authKeeper, am.bankKeeper, am.keeper, simState.TxConfig),
	))
	const (
		opWeightMsgUpdateStoredMeta          = "op_weight_msg_metastore"
		defaultWeightMsgUpdateStoredMeta int = 100
	)

	var weightMsgUpdateStoredMeta int
	simState.AppParams.GetOrGenerate(opWeightMsgUpdateStoredMeta, &weightMsgUpdateStoredMeta, nil,
		func(_ *rand.Rand) {
			weightMsgUpdateStoredMeta = defaultWeightMsgUpdateStoredMeta
		},
	)
	operations = append(operations, simulation.NewWeightedOperation(
		weightMsgUpdateStoredMeta,
		metastoresimulation.SimulateMsgUpdateStoredMeta(am.authKeeper, am.bankKeeper, am.keeper, simState.TxConfig),
	))
	const (
		opWeightMsgDeleteStoredMeta          = "op_weight_msg_metastore"
		defaultWeightMsgDeleteStoredMeta int = 100
	)

	var weightMsgDeleteStoredMeta int
	simState.AppParams.GetOrGenerate(opWeightMsgDeleteStoredMeta, &weightMsgDeleteStoredMeta, nil,
		func(_ *rand.Rand) {
			weightMsgDeleteStoredMeta = defaultWeightMsgDeleteStoredMeta
		},
	)
	operations = append(operations, simulation.NewWeightedOperation(
		weightMsgDeleteStoredMeta,
		metastoresimulation.SimulateMsgDeleteStoredMeta(am.authKeeper, am.bankKeeper, am.keeper, simState.TxConfig),
	))

	return operations
}

// ProposalMsgs returns msgs used for governance proposals for simulations.
func (am AppModule) ProposalMsgs(simState module.SimulationState) []simtypes.WeightedProposalMsg {
	return []simtypes.WeightedProposalMsg{}
}
