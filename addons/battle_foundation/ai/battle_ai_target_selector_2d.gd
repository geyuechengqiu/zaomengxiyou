extends Resource
class_name BattleAITargetSelector2D
#region 可替换的目标评分策略
@export_enum("nearest", "lowest_health", "highest_attack") var mode: String = "nearest"
## 非空时优先指定定义；没有符合者再选择普通敌对目标。
@export var preferred_definition: StringName = &""

func select_target(actor: BattleEntity2D, profile: BattleAIProfile2D, home: Vector2) -> BattleEntity2D:
	var result: BattleEntity2D
	var best: float = INF
	for candidate in actor.session.get_entities():
		if not candidate is BattleEntity2D or candidate == actor or candidate.is_queued_for_deletion() or not candidate.is_alive():
			continue
		if not actor.session.factions.is_hostile(actor.faction_id, candidate.faction_id):
			continue
		var offset: Vector2 = candidate.global_position - actor.global_position
		if absf(offset.x) > profile.detection_range or absf(offset.y) > profile.vertical_range or absf(candidate.global_position.x - home.x) > profile.leash_radius:
			continue
		var score := score_target(actor, candidate)
		if not preferred_definition.is_empty() and candidate.definition_id != preferred_definition:
			score += 1000000000.0
		if score < best:
			best = score
			result = candidate
	return result

## 新目标规则继承此资源并覆盖评分，不需要修改动作或伤害代码。
func score_target(actor: BattleEntity2D, candidate: BattleEntity2D) -> float:
	match mode:
		"lowest_health": return candidate.attributes.get_vital_value(&"health")
		"highest_attack": return -candidate.attributes.get_value(&"atk")
	return actor.global_position.distance_squared_to(candidate.global_position)
#endregion
