extends Resource
class_name CoreOperationProfile

#region 配置与运行状态
## 可复用映射资源：意图 -> InputMap 动作列表；轴 -> 负/正意图。不包含游戏动作规则。
@export var bindings: Dictionary = {}
@export var axes: Dictionary = {}
## InputMap 默认物理键名，由绑定服务安装；运行时改键不写回此资源。
@export var default_keys: Dictionary = {}
@export var reserved_keys: Array[String] = []
@export var buffered_intents: Array[StringName] = []
@export var buffer_seconds: float = 0.2
@export var buffer_capacity: int = 16
@export var long_press_seconds: float = 0.3
@export var double_tap_intents: Array[StringName] = []
@export var double_tap_seconds: float = 0.25
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
