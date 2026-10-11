extends Node
#region 原版固定样例与真实GAS/装备/Buff通知链
var checks: int = 0
var failures: Array[String] = []
var scene: Node2D
var player: BattleEntity2D
var attributes: BattleAttributeComponent
var display: OriginalFightPowerDisplay

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func check_power(expected: int, message: String) -> void:
	check(attributes.get_fight_power() == expected and int(attributes.get_snapshot().fightPower) == expected and display.number == expected, "%s [expected=%d computed=%d display=%d]" % [message,expected,attributes.get_fight_power(),display.number])

func _ready() -> void:
	var rules := load("res://data/attribute/fight_power_rules.tres") as BattleFightPowerRules
	var source: Dictionary = rules.source_config.data
	var original: Dictionary = source.roles["孙悟空"].base_attributes
	var expected_weights := {"hpMax":1.0,"mpMax":2.0,"atk":12.0,"phyDef":40.0,"hit":4.0,"dodge":6.0,"critical":6.0,"toughness":4.0,"lucky":6.0,"guardian":4.0,"reHP":180.0,"reMP":360.0}
	check(source.weights == expected_weights, "十二项权重与原PowerAttribute[1]一致")
	check(source.roles["孙悟空"].powerCorrection == 190 and source.original_tip.contains("修正战力"), "原Role2001修正190及Tips684组成说明")
	check(source.archive_sha256.length() == 64 and source.logic.size() == 2, "原版配置和公式保留SHA256溯源")
	check(rules.calculate(original) == 987 and rules.calculate(original,190) == 1177, "一级原版987；显式启用190修正才为1177")
	check(rules.calculate({&"critical":10,&"toughness":10,&"lucky":10,&"guardian":10,&"hit":10,&"dodge":10}) == 300, "评分直接乘权重，不转换为暴击/闪避/幸运概率")
	check(rules.calculate({&"hpMax":0.49}) == 0 and rules.calculate({&"hpMax":0.5}) == 1 and rules.calculate({&"hpMax":-0.5}) == 0, "AS3 Math.round使用floor(sum+0.5)，非逐属性取整")
	check(rules.calculate({&"hpMax":0.25,&"mpMax":0.125}) == 1, "多个小数项先相加再取整")
	check(rules.calculate({&"hp":10000,&"mp":10000,&"exp":10000,&"level":81,&"fireResist":10000,&"critical_rate":1}) == 0, "当前生命/魔法/经验/等级/抗性/概率不作为直接战力项")
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	add_child(scene)
	scene.session.set_physics_process(false)
	scene.flow.stop()
	player = scene.player
	attributes = player.attributes
	display = scene.original_hud.inventory_view.get_node("FightPower")
	check(attributes.get_value(&"reMP") == 0, "真实开局场景回魔为原版0")
	check_power(987, "真实开局、属性快照及背包为原版987")
	attributes.set_level(1)
	attributes.begin_update()
	for id in original: attributes.set_base_value(StringName(id),float(original[id]))
	attributes.end_update()
	check(attributes.fight_power_correction == 0, "参考离线服务端不另加职业修正")
	check_power(987, "角色、属性快照及背包统一读取原战力")
	var breakdown := attributes.get_fight_power_breakdown()
	check(breakdown.attribute_power == 987 and breakdown.correction == 0 and breakdown.contributions.atk == 312 and breakdown.contributions.phyDef == 200, "拆分属性战力、修正值和每项贡献，可解释显示数字")
	attributes.set_level(2)
	check(is_equal_approx(attributes.get_layer_value(&"atk",false,false),31.25) and attributes.get_value(&"atk") == 31, "原成长攻击保留31.25参与战力，战斗面板仍显示整数31")
	check_power(1187, "原二级裸装：330＋120×2＋31.25×12＋6.05×40＝1187")
	attributes.set_level(81)
	check_power(16987, "原81级裸装四项成长样例16987，不重复加入成长")
	attributes.set_level(1)
	attributes.set_base_value(&"atk",26.125)
	check_power(989, "GM基础属性小数按原公式总和取整，不沿用面板中间整数")
	attributes.set_base_value(&"atk",26)
	attributes.get_vital(&"health").modify_value(-100)
	attributes.get_vital(&"mana").modify_value(-50)
	check_power(987, "受伤及耗蓝不降低战力")
	var buff := load("res://data/buffs/attack_up.tres") as GameplayStatusData
	player.statuses.apply_status(buff,player)
	check(attributes.get_value(&"atk") > 26, "实际GAS加攻Buff改变战斗攻击")
	check_power(987, "临时加攻Buff不抬高长期战力")
	player.statuses.remove_status(buff.status_id)
	check_power(987, "Buff移除不留下战力残留")
	var inventory := player.inventory as OriginalInventory
	var armor := inventory.get_owned_item(load("res://data/inventory/110101001.tres")) as Equip
	var weapon := inventory.get_owned_item(load("res://data/inventory/110101003.tres")) as Equip
	inventory.equip_item(armor)
	check_power(1101, "原封煞甲34生命＋2防御提供114战力，穿戴即时通知")
	inventory.equip_item(weapon)
	check_power(1191, "原封魔棒6攻击＋3暴击评分提供90战力，叠加已装备防具")
	check(inventory.set_item_additions(weapon,{&"atk":2}), "随机附加属性走背包插件统一入口")
	check_power(1215, "装备附加2攻击增加24战力，不重复计算基础装备")
	inventory.unequip_item(weapon)
	check_power(1101, "卸下武器移除基础及附加属性战力")
	inventory.unequip_item(armor)
	check_power(987, "卸下所有装备恢复原裸装战力")
	attributes.replace_source(&"equipment.sets",[GameplayAttributeModifier.new(&"atk",10)])
	check_power(1107, "套装永久加攻统一参与战力")
	attributes.replace_source(&"equipment.sets",[])
	check_power(987, "套装失效撤销战力")
	attributes.replace_source(&"test.temporary",[GameplayAttributeModifier.new(&"hpMax",100),GameplayAttributeModifier.new(&"critical",200)])
	check(attributes.get_value(&"hpMax") == 375 and attributes.get_value(&"critical") == 200, "临时生命上限/暴击评分仍影响实际战斗")
	check_power(987, "临时生命上限和暴击评分不参与战力")
	attributes.replace_source(&"test.temporary",[])
	var other: BattleEntity2D = scene.session.spawn_entity_2d("characters",&"孙悟空")
	check(other != null, "同配置角色实例可独立创建")
	if other != null:
		var power: int = other.attributes.get_fight_power()
		attributes.set_base_value(&"atk",36)
		check(other.attributes.get_fight_power() == power and display.number == 1107, "GM更新即时刷新，其他角色属性和战力不受污染")
	attributes.set_base_value(&"atk",26)
	var cover := GameplayAttributeModifier.new(&"atk",100)
	cover.modifier_type = GameplayAttributeModifier.ModifierType.OVERRIDE
	attributes.replace_source(&"test.temporary_cover",[cover])
	attributes.replace_source(&"equipment.fractional",[GameplayAttributeModifier.new(&"atk",0.125)])
	check(attributes.get_value(&"atk") == 100, "临时覆盖仍决定实际战斗攻击")
	check_power(989, "整数最终值被临时覆盖时，装备小数变更仍立即刷新原战力")
	attributes.replace_source(&"equipment.fractional",[])
	check_power(987, "被临时覆盖的装备加成移除也无战力残留")
	attributes.replace_source(&"test.temporary_cover",[])
	scene.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS original fight power: %d checks; shipped weights/correction, AS3 rounding/raw growth, GAS snapshot/UI, equipment/additions/sets, Buff/vital exclusions and isolation" % checks)
		get_tree().quit()
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)
#endregion
