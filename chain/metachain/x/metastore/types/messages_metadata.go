package types

func NewMsgSendMetadata(
	creator string,
	port string,
	channelID string,
	timeoutTimestamp uint64,
	url string,
	addresses []string,
) *MsgSendMetadata {
	return &MsgSendMetadata{
		Creator:          creator,
		Port:             port,
		ChannelID:        channelID,
		TimeoutTimestamp: timeoutTimestamp,
		Url:              url,
		Addresses:        addresses,
	}
}
