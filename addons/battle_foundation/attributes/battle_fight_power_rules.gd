extends Resource
class_name BattleFightPowerRules
#region 原版PowerAttribute权重；角色原始评分不换算为战斗概率
const ATTRIBUTES: Array[StringName] = [&"hpMax", &"mpMax", &"atk", &"phyDef", &"hit", &"dodge", &"critical", &"toughness", &"lucky", &"guardian", &"reHP", &"reMP"]
@export var source_config: JSON

func get_breakdown(attributes: Dictionary, correction: float = 0.0) -> Dictionary:
	var weights: Dictionary = source_config.data.get("weights", {}) if source_config != null else {}
	var contributions := {}
	# AS3先计算前六项，再加后六项；中间不取整，仅在总和处Math.round。
	var first_half := 0.0
	var second_half := 0.0
	for index in range(ATTRIBUTES.size()):
		var id: StringName = ATTRIBUTES[index]
		var contribution := float(attributes.get(id, 0.0)) * float(weights.get(String(id), 0.0))
		contributions[id] = contribution
		if index < 6: first_half += contribution
		else: second_half += contribution
	var weighted_sum := first_half + second_half
	return {"attributes": attributes.duplicate(), "contributions": contributions, "weighted_sum": weighted_sum,
		"attribute_power": int(floor(weighted_sum + 0.5)), "correction": correction,
		"total": int(floor(weighted_sum + correction + 0.5))}

func calculate(attributes: Dictionary, correction: float = 0.0) -> int:
	return int(get_breakdown(attributes, correction).total)
#endregion
