package types

// GetBytes is a helper for serialising
func (p ChunkPacketData) GetBytes() ([]byte, error) {
	var modulePacket DatastorePacketData

	modulePacket.Packet = &DatastorePacketData_ChunkPacket{&p}

	return modulePacket.Marshal()
}
