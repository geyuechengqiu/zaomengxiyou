extends Resource
class_name BattleBossSkillRule
#region 共享技能选择与播报定义
@export var ability_id: StringName
@export var priority: int = 0
@export var weight: float = 1.0
@export var cooldown_group: StringName
@export var group_cooldown: float = 0.0
@export var attack_range: float = 600.0
@export var vertical_range: float = 400.0
@export var minimum_range: float = 0.0
@export_range(0, 1) var minimum_health_ratio: float = 0.0
@export_range(0, 1) var maximum_health_ratio: float = 1.0
@export var phase_ids: Array[StringName] = []
@export var required_conditions: Array[StringName] = []
@export var requires_no_summons: bool = false
@export var announcement: Texture2D
## 原版SkillComing与动作同时开始；可扩展Boss允许先播报再开始动作。
@export var announcement_lead_seconds: float = 0.0
@export var warning_rect: Rect2

func is_valid() -> bool:
	for value in [weight, group_cooldown, attack_range, vertical_range, minimum_range, announcement_lead_seconds]:
		if not is_finite(value) or value < 0.0: return false
	return not ability_id.is_empty() and weight > 0 and attack_range > minimum_range and vertical_range > 0 and minimum_health_ratio >= 0 and maximum_health_ratio <= 1 and minimum_health_ratio <= maximum_health_ratio and warning_rect.position.is_finite() and warning_rect.size.is_finite() and warning_rect.size.x >= 0 and warning_rect.size.y >= 0
#endregion
