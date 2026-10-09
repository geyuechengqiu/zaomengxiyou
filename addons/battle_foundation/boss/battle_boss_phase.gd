extends Resource
class_name BattleBossPhase
#region 血量阈值阶段：定义不保存触发状态
@export var phase_id: StringName
@export_range(0, 1) var health_ratio: float = 0.5
@export var entry_ability_id: StringName
@export var required_conditions: Array[StringName] = []
@export var invulnerable_during_entry: bool = false
@export var scene_event: StringName
@export var display_name: String

func is_valid() -> bool:
	return not phase_id.is_empty() and is_finite(health_ratio) and health_ratio > 0.0 and health_ratio < 1.0
#endregion
