extends RefCounted
class_name BattleRandom
#region 随机数状态
## 战斗、掉落和出生点等命名流互不消耗对方序列。快照用 Variant，勿转换为浮点 JSON。
var _seed: int = 0
var _streams: Dictionary = {}
#endregion
#region 公共接口
func initialize(value: int) -> void:
	_seed = value
	_streams.clear()

func random_float(stream: StringName = &"combat") -> float:
	return _get_stream(stream).randf()

func random_int(minimum: int, maximum: int, stream: StringName = &"combat") -> int:
	assert(minimum <= maximum, "随机数范围不合法")
	return _get_stream(stream).randi_range(minimum, maximum)

func roll(probability: float, stream: StringName = &"combat") -> bool:
	return random_float(stream) < clampf(probability, 0.0, 1.0)

func snapshot() -> Dictionary:
	var states := {}
	for id in _streams:
		states[id] = _streams[id].state
	return {"seed": _seed, "states": states}

func restore(data: Dictionary) -> void:
	initialize(int(data.seed))
	for id in data.states:
		_get_stream(StringName(id)).state = int(data.states[id])
#endregion
#region 内部实现
func _get_stream(id: StringName) -> RandomNumberGenerator:
	if not _streams.has(id):
		var generator := RandomNumberGenerator.new()
		generator.seed = (str(_seed) + ":" + String(id)).hash()
		_streams[id] = generator
	return _streams[id]
#endregion
