extends RefCounted
class_name CoreOperationBuffer
#region 独立可消费意图队列
## 缓存按下边沿，保留同帧短按和每次连按；消费一个 sequence 不会清掉后续连按。
var _entries: Array[Dictionary] = []
#endregion
#region 有界队列与输入时间
func append(intent: CoreOperationIntent, seconds: float, capacity: int) -> void:
	if seconds <= 0.0 or capacity <= 0:
		return
	while _entries.size() >= capacity:
		_entries.pop_front()
	_entries.append({"intent": intent.copy_intent(), "expires_at": intent.input_time + seconds})

func peek(now: float) -> Array[CoreOperationIntent]:
	clean_expired(now)
	var result: Array[CoreOperationIntent] = []
	for entry in _entries:
		result.append((entry.intent as CoreOperationIntent).copy_intent())
	return result

func consume(sequence: int) -> bool:
	for index in range(_entries.size()):
		if _entries[index].intent.sequence == sequence:
			_entries.remove_at(index)
			return true
	return false

func clear(action: StringName = &"") -> void:
	if action.is_empty():
		_entries.clear()
		return
	for index in range(_entries.size() - 1, -1, -1):
		if _entries[index].intent.action == action:
			_entries.remove_at(index)

func clean_expired(now: float) -> void:
	for index in range(_entries.size() - 1, -1, -1):
		if now >= _entries[index].expires_at:
			_entries.remove_at(index)
#endregion
