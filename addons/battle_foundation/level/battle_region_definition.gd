extends Resource
class_name BattleRegionDefinition
#region 区域只读定义
@export var region_id: StringName
@export var display_name: String
@export var bounds: Rect2
@export var entry_rect: Rect2
@export var exit_rect: Rect2
@export var wave_ids: Array[StringName] = []
@export var required_conditions: Array[StringName] = []
@export var automatic_exit: bool = true
## 自动切区时向左扩大检测，单位为世界像素；最终出口仍用原exit_rect。
@export_range(0.0, 4096.0, 1.0) var camera_transition_margin: float = 0.0

func get_automatic_exit_rect() -> Rect2:
	return exit_rect.grow_individual(camera_transition_margin, 0, 0, 0).intersection(bounds)
#endregion
