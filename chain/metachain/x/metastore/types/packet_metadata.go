package types

// GetBytes is a helper for serialising
func (p MetadataPacketData) GetBytes() ([]byte, error) {
	var modulePacket MetastorePacketData

	modulePacket.Packet = &MetastorePacketData_MetadataPacket{&p}

	return modulePacket.Marshal()
}
