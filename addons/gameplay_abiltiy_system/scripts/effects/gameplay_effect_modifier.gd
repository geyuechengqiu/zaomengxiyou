extends Resource
class_name GameplayEffectModifier
#region 配置与运行状态

## 通用技能效果参数修改器，可由任意外部系统注入。
## 留空时影响所有技能，否则只影响对应的技能 ID。
@export var ability_id: StringName = &""
@export var damage_multiplier: float = 1.0
@export var heal_multiplier: float = 1.0
@export var duration_multiplier: float = 1.0
@export var duration_add: float = 0.0
@export var range_multiplier: float = 1.0
#endregion
#region 公共接口

func affects_ability(id: StringName) -> bool:
	return ability_id.is_empty() or ability_id == id

func apply_to_context(context: Dictionary) -> void:
	for key in ["damage_multiplier", "heal_multiplier", "duration_multiplier", "range_multiplier"]:
		var multiplier: float = get(key)
		if multiplier != 1.0:
			context[key] = context.get(key, 1.0) * multiplier
	if duration_add != 0.0:
		context["duration_add"] = context.get("duration_add", 0.0) + duration_add
#endregion
