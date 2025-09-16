package types

func NewMsgSendChunk(
	creator string,
	port string,
	channelID string,
	timeoutTimestamp uint64,
	index string,
	data []byte,
) *MsgSendChunk {
	return &MsgSendChunk{
		Creator:          creator,
		Port:             port,
		ChannelID:        channelID,
		TimeoutTimestamp: timeoutTimestamp,
		Index:            index,
		Data:             data,
	}
}
