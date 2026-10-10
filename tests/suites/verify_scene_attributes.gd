extends Node
#region 场景属性保存与真实战斗验收
var checks: int = 0
var failures: Array[String] = []
const BACKUP := "res://.cleanup-backup/scene-attributes"

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(BACKUP)
	await _verify_saved_character()
	await _verify_saved_arena()
	_verify_validation()
	if failures.is_empty():
		print("PASS scene attributes: %d checks; Inspector exports, saved scene values, level/growth/vitals, instance isolation, shared resource safety, actual panel/damage and sample restoration" % checks)
		get_tree().quit()
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _save(scene: Node, path: String) -> PackedScene:
	var packed := PackedScene.new()
	_check(packed.pack(scene) == OK, "编辑后的组件值能打包到场景")
	_check(ResourceSaver.save(packed, path) == OK, "组件值保存到tscn")
	scene.free()
	return ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
#endregion
#region 基础属性在成长之前应用，初始Vital使用修改后的上限
func _verify_saved_character() -> void:
	var template := load("res://data/battle2d/sunwukong_2d.tscn") as PackedScene
	var edited := template.instantiate() as BattleEntity2D
	var component := edited.get_node("GameplayVitalAttributeComponent") as BattleAttributeComponent
	var properties := {}
	for property in component.get_property_list():
		properties[property.name] = property.usage
	_check(int(properties.base_values) & PROPERTY_USAGE_EDITOR != 0 and int(properties.initial_level_override) & PROPERTY_USAGE_EDITOR != 0, "基础值和初始等级直接暴露给Inspector")
	_check(int(properties._active_sets) & PROPERTY_USAGE_EDITOR == 0 and int(properties._vitals) & PROPERTY_USAGE_EDITOR == 0, "隐藏会被装配覆盖的旧内部数组编辑入口")
	component.base_values[&"hpMax"] = 500
	component.base_values[&"mpMax"] = 180
	component.base_values[&"atk"] = 84
	component.base_values[&"phyDef"] = 16
	component.base_values[&"walkSpeed"] = 315
	component.initial_level_override = 3
	var untouched := template.instantiate() as BattleEntity2D
	_check((untouched.get_node("GameplayVitalAttributeComponent") as BattleAttributeComponent).base_values[&"atk"] == 26, "每个实例的编辑字典独立，不污染角色模板")
	untouched.free()
	var saved := _save(edited, BACKUP + "/edited-wukong.tscn")
	var actor := saved.instantiate() as BattleEntity2D
	component = actor.get_node("GameplayVitalAttributeComponent")
	_check(component.base_values[&"atk"] == 84 and component.initial_level_override == 3, "重新加载保留组件中的属性和等级")
	var session := BattleSystem.create_session(self, "res://data/battle2d/manifest.json", 19)
	session.set_physics_process(false)
	var definition := session.catalog.instantiate_definition("characters", &"孙悟空") as BattleEntityDefinition
	actor.initialize_battle(session, &"verification/scene-values", definition)
	session.add_child(actor)
	_check(component.current_level == 3 and component.get_attribute(&"atk").base_value == 84 and component.get_value(&"atk") == 95, "组件一级攻击先应用，再叠加原版等级成长与取整")
	_check(component.get_value(&"hpMax") == 610 and component.get_vital_value(&"health") == 610, "提高生命基础与初始等级后，出生生命填满最终上限")
	_check(component.get_value(&"mpMax") == 220 and component.get_vital_value(&"mana") == 220 and component.get_value(&"phyDef") == 18, "魔法、防御使用相同基础与成长链")
	_check(component.get_value(&"walkSpeed") == 315, "其他基础属性也使用组件编辑值")
	var notices: Array[Dictionary] = []
	component.snapshot_changed.connect(func(snapshot): notices.append(snapshot))
	component.set_base_value(&"atk", 82)
	_check(component.get_value(&"atk") == 93 and not notices.is_empty() and notices[-1][&"atk"] == 93, "运行时GM入口继续统一计算并通知最终值")
	var peer := session.spawn_entity_2d("characters", &"孙悟空")
	_check(peer.attributes.get_value(&"atk") == 26 and peer.attributes.current_level == 1 and peer.attributes.get_vital_value(&"health") == 275, "同类角色未被本地场景修改污染")
	var source := load("res://data/battle2d/sunwukong_attributes.tres") as GameplayAttributeSet
	for attribute: GameplayAttribute in source.attributes:
		if attribute.attribute_id == &"atk":
			_check(source.attributes[attribute] == 26, "原始共享属性资源未被组件初始化写回")
	actor.free()
	session.free()
	await get_tree().process_frame
#endregion
#region 样例启动与切换样例尊重实际场景组件，下一次攻击一致
func _verify_saved_arena() -> void:
	var arena: Node = load("res://tests/fixtures/original_damage_demo.tscn").instantiate()
	_check(arena.is_editable_instance(arena.get_node("BattleSession/Actors/SunWukong")), "样例默认开放角色可编辑子节点")
	var component := arena.get_node("BattleSession/Actors/SunWukong/GameplayVitalAttributeComponent") as BattleAttributeComponent
	_check(component.base_values[&"atk"] == 100, "原版伤害样例的100攻击是可见场景配置")
	component.base_values[&"atk"] = 150
	component.base_values[&"hpMax"] = 600
	component.initial_level_override = 2
	var saved := _save(arena, BACKUP + "/edited-arena.tscn")
	var demo: Node = saved.instantiate()
	add_child(demo)
	demo.set_process(false)
	demo.session.set_physics_process(false)
	demo.operations.enabled = false
	var player: BattleEntity2D = demo.player
	_check(player.attributes.get_value(&"atk") == 155 and player.attributes.current_level == 2 and player.attributes.get_vital_value(&"health") == 655, "样例ready没有把组件编辑值覆盖回脚本常量")
	demo._process(0)
	_check("等级2" in demo.info.text and "攻击155" in demo.info.text, "样例面板显示修改后的等级与最终攻击")
	for tick in range(8):
		await get_tree().physics_frame
		demo.session.advance_physics(1.0 / 60.0)
	var target: BattleEntity2D = demo.dummies[1]
	var health := target.attributes.get_vital_value(&"health")
	_check(player.try_attack(), "组件编辑后能正常释放GAS普攻")
	for tick in range(25):
		await get_tree().physics_frame
		demo.session.advance_physics(1.0 / 60.0)
	_check(health - target.attributes.get_vital_value(&"health") == 135, "下一次真实攻击使用155减20防御，面板与伤害一致")
	demo.set_sample(3)
	_check(player.attributes.get_value(&"atk") == 155, "切换固定附伤样例保留组件基础攻击")
	demo.set_sample(1)
	_check(player.attributes.get_value(&"critical") == 156.25, "暴击验收样例仍可临时配置评分")
	demo.set_sample(0)
	_check(player.attributes.get_value(&"critical") == player.attributes.get_initial_base_value(&"critical"), "退出暴击样例恢复组件的基础评分")
	demo.free()
	await get_tree().process_frame
#endregion
#region 不合法编辑在初始化前拒绝
func _verify_validation() -> void:
	var actor := load("res://data/battle2d/sunwukong_2d.tscn").instantiate() as BattleEntity2D
	var component := actor.get_node("GameplayVitalAttributeComponent") as BattleAttributeComponent
	var definition := load("res://data/battle2d/sunwukong.tres") as BattleEntityDefinition
	component.base_values[&"typo"] = 1
	_check("typo" in actor.get_component_configuration_error(definition), "属性ID拼写错误在绑定前给出配置错误")
	component.base_values.erase(&"typo")
	component.initial_level_override = 221
	_check("等级" in actor.get_component_configuration_error(definition), "超过原版220级上限的初始等级被拒绝")
	component.initial_level_override = 1
	component.base_values[&"atk"] = INF
	_check("atk" in actor.get_component_configuration_error(definition), "非有限属性值被拒绝")
	component.base_values[&"atk"] = 26
	component.base_values[&"level"] = 2
	_check("Initial Level Override" in actor.get_component_configuration_error(definition), "等级只使用一个明确配置入口")
	actor.free()
#endregion
