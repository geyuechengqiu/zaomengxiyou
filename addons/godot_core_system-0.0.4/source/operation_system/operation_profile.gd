extends Resource
class_name CoreOperationProfile

#region 配置与运行状态
## 可复用映射资源：意图 -> InputMap 动作列表；轴 -> 负/正意图。不包含游戏动作规则。
@export var bindings: Dictionary = {}
@export var axes: Dictionary = {}
#endregion


#region 公共接口
func bind_intent(intent: StringName, actions: Array) -> void:
	bindings[intent] = actions.duplicate()


func bind_axis(axis: StringName, negative_intent: StringName, positive_intent: StringName) -> void:
	axes[axis] = {"negative": negative_intent, "positive": positive_intent}


func get_actions(intent: StringName) -> Array:
	var actions = bindings.get(intent, [])
	return actions if actions is Array else []
#endregion
