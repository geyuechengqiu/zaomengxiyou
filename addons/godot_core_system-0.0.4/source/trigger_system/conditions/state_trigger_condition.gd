extends TriggerCondition
class_name StateTriggerCondition
#region 配置与运行状态

## 状态触发条件，条件示例

## 状态名称
@export var state_name : StringName
## 状态值
@export var required_state : StringName
#endregion
#region 生命周期与引擎回调

func _init(config : Dictionary = {}) -> void:
	state_name = config.get("state_name", "")
	required_state = config.get("required_state", "")
#endregion
#region 公共接口

func evaluate(context: Dictionary) -> bool:
	var p_state_name = context.get("state_name", "")
	var p_state_value = context.get("state_value", "")
	if state_name != p_state_name:
		return true
	return p_state_value == required_state
#endregion
