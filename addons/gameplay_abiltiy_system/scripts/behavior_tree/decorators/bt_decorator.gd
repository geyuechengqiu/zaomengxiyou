extends BTNode
class_name BTDecorator
#region 配置与运行状态

@export var child: BTNode
#endregion
#region 公共接口

func reset(instance: BTInstance) -> void:
	_clear_storage(instance)
	if is_instance_valid(child):
		child.reset(instance)
#endregion
#region 内部实现

func _tick(instance: BTInstance, delta: float) -> int:
	if not is_instance_valid(child):
		return Status.FAILURE
	
	return _tick_decorator(instance, delta)

# 子类实现具体逻辑
func _tick_decorator(instance: BTInstance, delta: float) -> int:
	return child.tick(instance, delta)
#endregion
