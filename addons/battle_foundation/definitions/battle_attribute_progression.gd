extends Resource
class_name BattleAttributeProgression
#region 成长与经验定义
## 一级值在实体 attribute_set 中；这里仅保存每级增量和各级升级所需经验。
@export var attribute_set: GameplayAttributeSet
@export var growth_per_level: Dictionary[StringName, float] = {}
@export var experience_per_level: Array[float] = []
@export_range(1, 10000) var maximum_level: int = 1

func get_required_experience(level: int) -> float:
	if level >= maximum_level or level < 1 or level > experience_per_level.size():
		return 0.0
	return experience_per_level[level - 1]

func is_configuration_valid(attributes: Dictionary) -> bool:
	if maximum_level < 1:
		return false
	for id in growth_per_level:
		if not attributes.has(id) or id in [&"level", &"exp"] or not is_finite(growth_per_level[id]):
			return false
	if not experience_per_level.is_empty():
		if experience_per_level.size() < maximum_level - 1:
			return false
		for level in range(1, maximum_level):
			var required := get_required_experience(level)
			if not is_finite(required) or required <= 0.0:
				return false
	return true
#endregion
