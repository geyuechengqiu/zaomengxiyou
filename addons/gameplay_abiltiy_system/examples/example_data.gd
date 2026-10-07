extends RefCounted
#region 公共接口

## 独立演示数据，只使用技能系统插件自身的类型。
static func attribute_sets() -> Array[GameplayAttributeSet]:
	var attributes := GameplayAttributeSet.new()
	var values := {
		&"strength": 10.0, &"agility": 8.0, &"intelligence": 12.0,
		&"vitality": 10.0, &"hpMax": 100.0, &"mpMax": 80.0,
		&"atk": 20.0, &"phyDef": 5.0, &"critical": 0.0,
		&"reHP": 0.0, &"reMP": 5.0,
	}
	for id in values:
		var attribute := GameplayAttribute.new()
		attribute.attribute_id = id
		attribute.attribute_display_name = String(id)
		attribute.min_value = 0.0
		attributes.attributes[attribute] = values[id]
	return [attributes]

static func vitals() -> Array[GameplayVital]:
	var mana := ManaVital.new()
	mana.regen_rate_attribute = &"reMP"
	return [HealthVital.new(), mana]

static func register_tags() -> void:
	for id in [&"Team.Enemy", &"state.invulnerable", &"status.debuff", &"element.fire", &"status.burn"]:
		if TagManager.is_tag_registered(id):
			continue
		var tag := GameplayTag.new()
		tag.id = id
		tag.display_name = String(id)
		TagManager.register_tag(tag)
#endregion
