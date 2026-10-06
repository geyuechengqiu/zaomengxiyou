extends "./compression_strategy.gd"
#region 公共接口

## Returns the input bytes without modification.
func compress(bytes: PackedByteArray) -> PackedByteArray:
	return bytes

## Returns the input bytes without modification.
func decompress(bytes: PackedByteArray) -> PackedByteArray:
	return bytes 
#endregion
