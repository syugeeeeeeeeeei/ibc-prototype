package types

import "cosmossdk.io/collections"

// StoredMetaKey is the prefix to retrieve all StoredMeta
var StoredMetaKey = collections.NewPrefix("storedMeta/value/")
