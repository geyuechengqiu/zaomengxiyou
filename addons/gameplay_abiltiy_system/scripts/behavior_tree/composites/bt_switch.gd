extends BTComposite
class_name BTSwitch
#region 配置与运行状态

@export var variable_key: String = ""
#endregion
#region 内部实现

func _tick(instance: BTInstance, delta: float) -> int:
	if variable_key.is_empty():
		push_warning("BTSwitch: variable key is empty!")
		return Status.FAILURE
	var index = instance.blackboard.get_var(variable_key, 0)
	if index < 0 or index >= children.size():
		push_warning("BTSwitch: index 不合法！")
		return Status.FAILURE
	return children[index].tick(instance, delta)
#endregion
