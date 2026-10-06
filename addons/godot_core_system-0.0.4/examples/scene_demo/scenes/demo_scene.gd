extends Control
#region 类型与常量

const CoreSceneManager = CoreSystem.CoreSceneManager
#endregion
#region 配置与运行状态

@onready var scene_manager : CoreSceneManager = CoreSystem.scene_manager
@onready var label = $Label
@onready var source_label = $SourceLabel

var _message: String = ""
var _source_scene: String = ""
#endregion
#region 公共接口


## 初始化场景状态
func init_state(data: Dictionary) -> void:
	if not is_node_ready():
		await ready
	if data.has("message"):
		_message = data.message
		label.text = _message
	else:
		label.text = name
		
	if data.has("source_scene"):
		_source_scene = data.source_scene
		source_label.text = "从场景 " + _source_scene + " 切换而来"
	else:
		source_label.text = "初始场景"

## 保存场景状态
func save_state() -> Dictionary:
	return {
		"message": _message if not _message.is_empty() else name,
		"source_scene": _source_scene
	}

## 恢复场景状态
func restore_state(data: Dictionary) -> void:
	if not is_node_ready():
		await ready
	if data.has("message"):
		_message = data.message
		label.text = _message
	if data.has("source_scene"):
		_source_scene = data.source_scene
		source_label.text = "从场景 " + _source_scene + " 切换而来"
#endregion
#region 信号回调

## 返回上一个场景
func _on_back_button_pressed() -> void:
	if scene_manager:
		scene_manager.pop_scene_async(
			CoreSceneManager.TransitionEffect.NONE,
			0.5
		)
#endregion
