extends BTAction
class_name BTModifyInt
#region 类型与常量

enum Operation { 
	SET,                ## 设置为指定值
	ADD,                ## 增加指定值
	SUBTRACT            ## 减少指定值
}
#endregion
#region 配置与运行状态

@export var variable_key: String = ""
@export var value: int = 1
@export var operation: Operation = Operation.ADD
#endregion
#region 内部实现

func _tick(instance: BTInstance, delta: float) -> int:
	var current_val: int = _get_var(instance, variable_key, 0)
	match operation:
		Operation.SET: current_val = value
		Operation.ADD: current_val += value
		Operation.SUBTRACT: current_val -= value
	_set_var(instance, variable_key, current_val)
	return Status.SUCCESS
#endregion
