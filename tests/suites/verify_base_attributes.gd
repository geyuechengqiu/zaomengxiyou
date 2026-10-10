extends Node
#region 资源与运行状态

const ROOT := "res://data/attribute/"
const BASE_SET = preload(ROOT + "sets/entity_base_attributes.tres")
const HEALTH = preload(ROOT + "vitals/health.tres")
const MANA = preload(ROOT + "vitals/mana.tres")
const GROUP_COUNTS := {"core": 12, "resistance": 8, "movement": 4, "protection": 4}
var _failed := false
#endregion
#region 验证入口

func _ready() -> void:
	var mapping: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source_mapping.json"))
	var ids: Dictionary = {}
	var fields: Dictionary = {}
	for row in mapping.attributes:
		_check(row.id == row.source_field, "属性 ID 应与原版字段完全一致，保留大小写")
		_check(row.resource == row.source_field + ".tres", "资源文件名应采用原版 ID")
		var definition := load(ROOT + row.resource) as GameplayAttribute
		_check(definition != null, "属性应能作为 GAS 资源加载：" + row.resource)
		if definition == null:
			continue
		_check(not ids.has(definition.attribute_id), "属性 ID 必须唯一")
		_check(not fields.has(row.source_field), "原版字段不能映射成两个独立数值")
		ids[definition.attribute_id] = true
		fields[row.source_field] = true
		_check(String(definition.attribute_id) == row.id, "索引 ID 应与资源一致")
		_check(definition.get_meta("source_field") == row.source_field, "资源应保留原字段溯源")
		_check(not definition.is_percentage, "本次导入的评分和抗性值都不是概率")
	_check(ids.size() == 28, "应覆盖全部 28 项共享定义")
	_check(BASE_SET.attributes.size() == ids.size(), "完整属性集应包含全部定义")
	var grouped_ids: Dictionary = {}
	for category in GROUP_COUNTS:
		var group := load(ROOT + "sets/" + category + "_attributes.tres") as GameplayAttributeSet
		_check(group != null and group.attributes.size() == GROUP_COUNTS[category], "分类属性集数量错误：" + category)
		if group == null:
			continue
		for definition: GameplayAttribute in group.attributes:
			_check(not grouped_ids.has(definition.attribute_id), "分类集不应重复注册同一属性")
			grouped_ids[definition.attribute_id] = true
	_check(grouped_ids.size() == ids.size(), "分类集合并应覆盖完整属性集")
	if _failed:
		get_tree().quit(1)
		return

	var attacker := Node3D.new()
	var target := Node3D.new()
	add_child(attacker)
	add_child(target)
	var first := GameplayVitalAttributeComponent.new()
	var second := GameplayVitalAttributeComponent.new()
	first.name = "GameplayVitalAttributeComponent"
	second.name = "GameplayVitalAttributeComponent"
	attacker.add_child(first)
	target.add_child(second)
	first.set_process(false)
	second.set_process(false)
	first.initialize([BASE_SET], [HEALTH, MANA])
	second.initialize([BASE_SET], [HEALTH, MANA])
	_check(first.has_attribute(&"atk") and first.has_attribute(&"phyDef"), "内置伤害策略所需 ID 应存在")
	_check(is_equal_approx(first.get_vital_value(&"health"), 1.0), "通用模板只提供 1 点可初始化生命")
	_check(is_zero_approx(first.get_vital_value(&"mana")), "无魔法实体应能使用零魔法上限")
	first.set_base_value(&"hpMax", 100.0)
	first.set_base_value(&"mpMax", 50.0)
	_check(is_equal_approx(first.get_vital(&"health").get_max_value(), 100.0), "最大生命应驱动 HealthVital 上限")
	_check(is_equal_approx(first.get_vital(&"mana").get_max_value(), 50.0), "最大魔法应驱动 ManaVital 上限")
	first.get_vital(&"health").modify_value(99.0)
	first.get_vital(&"mana").modify_value(50.0)
	first.modify_vital(&"health", -20.0)
	first.modify_vital(&"mana", -20.0)
	first.set_base_value(&"reHP", 5.0)
	first.set_base_value(&"reMP", 3.0)
	first.get_vital(&"health").process_regen(2.0)
	first.get_vital(&"mana").process_regen(2.0)
	_check(is_equal_approx(first.get_vital_value(&"health"), 90.0), "回血模板应按点/秒工作")
	_check(is_equal_approx(first.get_vital_value(&"mana"), 36.0), "回魔模板应按点/秒工作")
	first.set_base_value(&"critical", 2500.0)
	first.set_base_value(&"lucky", 4000.0)
	_check(is_equal_approx(first.get_value(&"critical"), 2500.0), "暴击评分不能截断到 1")
	_check(is_equal_approx(first.get_value(&"lucky"), 4000.0), "幸运评分不能截断到 1")
	first.set_base_value(&"waterResist", -20.0)
	first.set_base_value(&"jumpSpeed1", -178.0)
	_check(is_equal_approx(first.get_value(&"waterResist"), -20.0), "抗性应保留原版负弱点值")
	_check(is_equal_approx(first.get_value(&"jumpSpeed1"), -178.0), "跳跃应保留原版有符号速度")
	_check(is_equal_approx(first.get_value(&"protectPoint"), -1.0), "保护阈值应保留禁用值")
	first.set_base_value(&"atk", 20.0)
	var modifier := GameplayAttributeModifier.new(&"atk", 10.0)
	modifier.source_id = &"test.equipment"
	first.add_modifier(modifier)
	_check(is_equal_approx(first.get_value(&"atk"), 30.0), "共享资源应兼容 GAS 属性修改器")
	first.remove_modifiers_by_source(modifier.source_id)
	_check(is_equal_approx(first.get_value(&"atk"), 20.0), "按来源移除应恢复基础值")
	_check(is_zero_approx(second.get_value(&"atk")), "共享模板不能让另一实体属性被修改")
	_check(is_equal_approx(second.get_vital_value(&"health"), 1.0), "共享模板不能让另一实体 Vital 被修改")
	_check(BASE_SET.instantiate_attributes()[&"atk"].get_value() == 0.0, "模板初始值不能被实例修改")
	second.set_base_value(&"phyDef", 5.0)
	_check(is_equal_approx(DamageCalculator.calculate_final_damage(target, attacker, {}), 15.0), "默认伤害策略应直接读取原版 atk / phyDef")
	attacker.free()
	target.free()
	if not _failed:
		print("PASS: 28 个原版 ID、5 个属性集、2 个 Vital 模板、评分/负值、恢复/修改器、实体隔离及默认伤害结算")
	get_tree().quit(1 if _failed else 0)
#endregion
#region 失败处理

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)
#endregion
