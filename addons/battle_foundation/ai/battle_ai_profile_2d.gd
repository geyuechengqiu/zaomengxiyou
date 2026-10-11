extends Resource
class_name BattleAIProfile2D
#region 共享决策配置，不保存目标与计时器
@export var policy: Resource
@export var target_selector: BattleAITargetSelector2D
@export var attack_skill_id: StringName
@export_range(0.02, 1.0) var decision_interval: float = 0.1
@export var detection_range: float = 960.0
@export var vertical_range: float = 800.0
@export var leash_radius: float = 1100.0
@export var home_tolerance: float = 8.0
@export var attack_range: float = 150.0
@export var attack_vertical_range: float = 100.0
@export var minimum_attack_distance: float = 0.0
@export var patrol_radius: float = 300.0
@export var patrol_wait: float = 1.0
@export var jump_obstacles: bool = true
@export_range(0.0, 1.0) var flee_health_ratio: float = 0.0
@export_range(0.0, 1.0) var retreat_chance: float = 0.5
@export var retreat_minimum: float = 1.0
@export var retreat_maximum: float = 2.0
@export var maximum_retreat_distance: float = 500.0
@export var original_ai_id: int = 0

func is_valid() -> bool:
	if policy == null or not policy.has_method("decide"): return false
	for value in [decision_interval, detection_range, vertical_range, leash_radius, home_tolerance, attack_range, attack_vertical_range, minimum_attack_distance, patrol_radius, patrol_wait, flee_health_ratio, retreat_chance, retreat_minimum, retreat_maximum, maximum_retreat_distance]:
		if not is_finite(value) or value < 0.0:
			return false
	if flee_health_ratio > 1.0 or retreat_chance > 1.0:
		return false
	return policy != null and target_selector != null and is_finite(decision_interval) and decision_interval >= 0.02 and detection_range > 0.0 and leash_radius > 0.0 and attack_range > minimum_attack_distance and vertical_range > 0.0 and attack_vertical_range > 0.0 and patrol_radius >= 0.0 and patrol_radius < leash_radius and retreat_minimum >= 0.0 and retreat_maximum >= retreat_minimum and maximum_retreat_distance > 0.0
#endregion
