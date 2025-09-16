package metastore

import (
	autocliv1 "cosmossdk.io/api/cosmos/autocli/v1"

	"metachain/x/metastore/types"
)

// AutoCLIOptions implements the autocli.HasAutoCLIConfig interface.
func (am AppModule) AutoCLIOptions() *autocliv1.ModuleOptions {
	return &autocliv1.ModuleOptions{
		Query: &autocliv1.ServiceCommandDescriptor{
			Service: types.Query_serviceDesc.ServiceName,
			RpcCommandOptions: []*autocliv1.RpcCommandOptions{
				{
					RpcMethod: "Params",
					Use:       "params",
					Short:     "Shows the parameters of the module",
				},
				{
					RpcMethod: "ListStoredMeta",
					Use:       "list-stored-meta",
					Short:     "List all stored-meta",
				},
				{
					RpcMethod:      "GetStoredMeta",
					Use:            "get-stored-meta [id]",
					Short:          "Gets a stored-meta",
					Alias:          []string{"show-stored-meta"},
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "index"}},
				},
				// this line is used by ignite scaffolding # autocli/query
			},
		},
		Tx: &autocliv1.ServiceCommandDescriptor{
			Service:              types.Msg_serviceDesc.ServiceName,
			EnhanceCustomCommand: true, // only required if you want to use the custom command
			RpcCommandOptions: []*autocliv1.RpcCommandOptions{
				{
					RpcMethod: "UpdateParams",
					Skip:      true, // skipped because authority gated
				},
				{
					RpcMethod:      "CreateStoredMeta",
					Use:            "create-stored-meta [index] [url]",
					Short:          "Create a new stored-meta",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "index"}, {ProtoField: "url"}},
				},
				{
					RpcMethod:      "UpdateStoredMeta",
					Use:            "update-stored-meta [index] [url]",
					Short:          "Update stored-meta",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "index"}, {ProtoField: "url"}},
				},
				{
					RpcMethod:      "DeleteStoredMeta",
					Use:            "delete-stored-meta [index]",
					Short:          "Delete stored-meta",
					PositionalArgs: []*autocliv1.PositionalArgDescriptor{{ProtoField: "index"}},
				},
				// this line is used by ignite scaffolding # autocli/tx
			},
		},
	}
}
