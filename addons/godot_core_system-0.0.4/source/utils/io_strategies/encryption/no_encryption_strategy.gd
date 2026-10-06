extends "./encryption_strategy.gd"
#region 公共接口

## Returns the input bytes without modification.
func encrypt(bytes: PackedByteArray, _key: PackedByteArray) -> PackedByteArray:
	return bytes

## Returns the input bytes without modification.
func decrypt(bytes: PackedByteArray, _key: PackedByteArray) -> PackedByteArray:
	return bytes 
#endregion
