extends Resource
class_name TriggerCondition
#region 生命周期与引擎回调

## 触发条件
func _init(config : Dictionary = {}) -> void:
	pass
#endregion
#region 公共接口

func evaluate(context: Dictionary) -> bool:
	return true
#endregion
