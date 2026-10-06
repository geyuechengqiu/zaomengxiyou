extends TriggerCondition
class_name EventTypeTriggerCondition
#region 配置与运行状态

var event_type : StringName
#endregion
#region 生命周期与引擎回调

func _init(config : Dictionary = {}) -> void:
	event_type = config.get("event_type", "")
#endregion
#region 公共接口

func evaluate(context: Dictionary) -> bool:
	return context.get("event_type", "") == event_type
#endregion
