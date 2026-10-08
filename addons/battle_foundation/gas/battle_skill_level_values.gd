extends RefCounted
class_name BattleSkillLevelValues
#region 原版技能等级索引与释放快照
static func get_level(owner: Node, skill_id: StringName, context: Dictionary = {}) -> int:
	if context.has("skill_level"):
		return maxi(1, int(context.skill_level))
	return maxi(1, int(owner.get_damage_rules().skill_levels.get(skill_id, 1))) if owner.has_method("get_damage_rules") else 1

static func sample(values: Array[float], level: int) -> float:
	# MP/CD原表包含第0级；伤害固定附伤表由伤害策略按level-1读取。
	return values[clampi(level, 0, values.size() - 1)] if not values.is_empty() else 0.0

static func is_valid(values: Array[float]) -> bool:
	return not values.is_empty() and values.all(func(value: float): return is_finite(value) and value >= 0.0)
#endregion
