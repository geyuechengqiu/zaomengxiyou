extends BTAction
class_name BTWait
#region 配置与运行状态

## 等待时间（秒）
@export var duration: float = 1.0
## 从黑板读取等待时间的 Key（可选，如果设置则优先使用）
@export var duration_key: String = ""
#endregion
#region 内部实现

func _enter(instance: BTInstance):
	# 获取实际的等待时间（优先从黑板读取）
	var actual_duration = _get_actual_duration(instance)
	_set_storage(instance, maxf(0.0, actual_duration))

func _tick(instance: BTInstance, delta: float) -> int:
	var remaining: float = _get_storage(instance, 0.0)
	remaining = maxf(0.0, remaining - delta)
	_set_storage(instance, remaining)
	if remaining <= 0.0:
		return Status.SUCCESS
	return Status.RUNNING

func _get_actual_duration(instance: BTInstance) -> float:
	# 如果设置了 duration_key，优先从黑板读取
	if not duration_key.is_empty():
		var blackboard_duration = _get_var(instance, duration_key)
		if blackboard_duration != null and blackboard_duration is float:
			return blackboard_duration as float
	return duration
#endregion
