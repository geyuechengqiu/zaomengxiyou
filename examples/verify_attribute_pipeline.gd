extends Node
#region 验收入口
var checks: int = 0
var failures: Array[String] = []
var demo: Node2D
var attributes: BattleAttributeComponent
var notifications: Array[Dictionary] = []
var core_notifications: Array[Dictionary] = []

func _ready() -> void:
	demo = (load("res://examples/wukong_platform_demo.tscn") as PackedScene).instantiate()
	demo.enable_player_controls = false
	add_child(demo)
	demo.session.damage_strategy = SimpleDamageLogic.new()
	demo.session.set_physics_process(false)
	attributes = demo.player.attributes
	attributes.snapshot_changed.connect(func(snapshot): notifications.append(snapshot))
	CoreSystem.event_bus.event_pushed.connect(_on_core_attribute_event)
	for tick in range(8):
		await get_tree().physics_frame
		demo.session.advance_physics(1.0 / 60.0)
	_verify_growth_and_vitals()
	_verify_equipment_and_buffs()
	_verify_policies()
	_verify_monster_isolation()
	await _verify_attack()
	_verify_authored_animation()
	CoreSystem.event_bus.event_pushed.disconnect(_on_core_attribute_event)
	demo.session.clear_battle()
	demo.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS attribute pipeline: %d checks; growth/EXP, inventory swaps, GAS Buff stacking/expiry, vital policies, GM/UI/real damage, monster isolation and composed animation" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _equal(actual: float, expected: float, message: String) -> void:
	_check(is_equal_approx(actual, expected), "%s: actual=%s expected=%s" % [message, actual, expected])

func _on_core_attribute_event(id: String, payload: Array) -> void:
	if id == "battle.attributes.changed" and payload.size() == 1 and payload[0].get("source_entity_id") == demo.player.entity_id:
		core_notifications.append(payload[0])

func _panel_matches() -> void:
	_check(demo.attribute_info.text.contains("攻击 %.0f" % attributes.get_value(&"atk")) and demo.attribute_info.text.contains("等级 %d" % attributes.get_level()), "不等待下一帧，面板已显示最终属性")
#endregion
#region 原版成长与生命流程
func _verify_growth_and_vitals() -> void:
	_equal(attributes.get_value(&"hpMax"), 275, "一级生命上限")
	_equal(attributes.get_vital_value(&"health"), 275, "初始当前生命")
	attributes.modify_vital(&"health", -150)
	attributes.modify_vital(&"mana", -80)
	notifications.clear()
	core_notifications.clear()
	attributes.add_experience(110 + 170 + 5)
	_equal(attributes.get_level(), 3, "一次经验奖励能连续升级")
	_equal(attributes.get_value(&"exp"), 5, "升级逐级扣除经验，保留本级剩余")
	_equal(attributes.get_value(&"hpMax"), 385, "生命成长每级55")
	_equal(attributes.get_value(&"mpMax"), 140, "魔法成长每级20")
	_equal(attributes.get_value(&"atk"), 37, "攻击26+2*5.25，最终按原版取整")
	_equal(attributes.get_value(&"phyDef"), 7, "防御5+2*1.05，最终取整")
	_equal(attributes.get_vital_value(&"health"), 385, "升级生命回满")
	_equal(attributes.get_vital_value(&"mana"), 140, "升级魔法回满")
	_check(notifications.size() == 1 and notifications[0].hp == 385 and notifications[0].mp == 140, "升级只通知一次完整快照，Vital已同步")
	_check(core_notifications.size() == 1 and core_notifications[0].attributes == notifications[0], "Core统一事件与本地完整快照一致，且不包含中间升级状态")
	_panel_matches()
	attributes.set_base_value(&"level", 1)
	_equal(attributes.get_value(&"atk"), 26, "GM降级撤销旧成长")
	_equal(attributes.get_vital_value(&"health"), 275, "GM降级生命截断上限")
	attributes.current_level = 2
	_equal(attributes.get_value(&"atk"), 31, "直接等级属性也走统一成长入口")
	attributes.set_base_value(&"level", 1)
	attributes.set_base_value(&"exp", 0)
	attributes.set_base_value(&"atk", 40)
	_equal(attributes.get_value(&"atk"), 40, "基础属性修改即时重算")
	attributes.set_base_value(&"atk", 26)
	var exp_limit := attributes.progression.maximum_level
	attributes.set_level(exp_limit)
	attributes.add_experience(1000000000000.0)
	_equal(attributes.get_level(), exp_limit, "满级经验不会无限循环或越界")
	attributes.set_level(1)
	attributes.set_base_value(&"exp", 0)
#endregion
#region 插件装备、Buff与来源撤销
func _verify_equipment_and_buffs() -> void:
	attributes.get_vital(&"health").set_current_value(120)
	var vital_effect := GE_ModifyVital.new()
	vital_effect.vital_id = &"health"
	vital_effect.amount = 10.0
	var instant := GameplayStatusData.new()
	instant.duration = 0.0
	instant.apply_effects = [vital_effect]
	notifications.clear()
	demo.player.statuses.apply_status(instant, demo.player)
	_check(notifications.size() == 1 and notifications[0].hp == 130, "只有Vital变化的GAS效果事务也通知完整面板")
	attributes.get_vital(&"health").set_current_value(120)
	demo.toggle_attribute_equipment()
	_equal(attributes.get_value(&"atk"), 36, "Simple Inventory 装备事件加入攻击")
	_equal(attributes.get_value(&"hpMax"), 325, "装备加入生命上限")
	_equal(attributes.get_vital_value(&"health"), 120, "穿装备保留当前生命，不回满不保留比例")
	notifications.clear()
	demo.toggle_attribute_equipment()
	_equal(attributes.get_value(&"atk"), 26, "卸装攻击无残留")
	_equal(attributes.get_value(&"hpMax"), 275, "卸装生命加成无残留")
	_check(notifications.size() == 1, "卸装多项属性只发布一次快照")
	var first := (load("res://data/battle2d/equipment/attribute_test_weapon.tres") as BattleInventoryEquipment).duplicate(true) as BattleInventoryEquipment
	var second := first.duplicate(true) as BattleInventoryEquipment
	second.battle_definition.attribute_modifiers[0].value = 20
	demo.inventory.add_item(first)
	demo.inventory.equip_item(first)
	demo.inventory.add_item(second)
	notifications.clear()
	demo.inventory.equip_item(second)
	_equal(attributes.get_value(&"atk"), 46, "同槽替换先移除原装备")
	_check(notifications.size() == 1, "换装备不会通知中间脱装状态")
	demo.inventory.unequip_item(second)
	var buff := (load("res://data/battle2d/statuses/attribute_test_buff.tres") as GameplayStatusData).duplicate(true) as GameplayStatusData
	buff.max_stacks = 3
	buff.stacking_policy = StackingIntensity.new()
	demo.player.statuses.apply_status(buff, demo.player)
	_equal(attributes.get_value(&"atk"), 31, "GAS临时攻击倍率参与最终取整")
	_equal(attributes.get_value(&"hpMax"), 375, "Buff生命上限")
	_equal(attributes.get_vital_value(&"health"), 120, "Buff不补生命")
	notifications.clear()
	demo.player.statuses.apply_status(buff, demo.player)
	_equal(attributes.get_value(&"atk"), 36, "Buff叠层替换效果，不残留旧层")
	_equal(attributes.get_value(&"hpMax"), 475, "两层生命上限")
	_check(notifications.size() == 1, "Buff叠层是单次事务")
	var detail := attributes.get_breakdown(&"atk")
	_check(detail.base == 26 and detail.temporary.size() == 1 and detail.final == 36, "可追踪基础、成长、装备和临时层")
	attributes.set_level(2)
	_equal(attributes.get_vital_value(&"health"), 330, "原版升级只补非临时生命上限，Buff上限不用于补满")
	_equal(attributes.get_value(&"hpMax"), 530, "升级后保留临时上限")
	demo.player.statuses.advance_simulation(8.1)
	_equal(attributes.get_value(&"hpMax"), 330, "Buff过期撤销全部生命加成")
	_equal(attributes.get_value(&"atk"), 31, "Buff过期撤销倍率")
	_panel_matches()
	attributes.set_level(1)
	var template := GameplayAttributeModifier.new(&"atk", 7)
	attributes.replace_source(&"temporary.gm", [template])
	attributes.replace_source(&"temporary.gm", [template])
	_equal(attributes.get_value(&"atk"), 33, "同临时来源替换而非重复加成")
	_check(template.source_id.is_empty(), "不修改共享修改器模板")
	attributes.remove_modifiers_by_source(&"temporary.gm")
	_equal(attributes.get_value(&"atk"), 26, "按来源撤销临时属性")
#endregion
#region 可选择的上限策略与实体隔离
func _verify_policies() -> void:
	var vital := attributes.get_vital(&"health")
	vital.set_current_value(100)
	vital.max_change_policy = GameplayVital.MaxChangePolicy.KEEP_RATIO
	attributes.set_base_value(&"hpMax", 550)
	_equal(vital.current_value, 200, "可选保留比例策略")
	vital.max_change_policy = GameplayVital.MaxChangePolicy.ADD_DELTA
	attributes.set_base_value(&"hpMax", 600)
	_equal(vital.current_value, 250, "可选补充上限增量策略")
	vital.max_change_policy = GameplayVital.MaxChangePolicy.FILL
	attributes.set_base_value(&"hpMax", 700)
	_equal(vital.current_value, 700, "可选回满策略")
	vital.max_change_policy = GameplayVital.MaxChangePolicy.KEEP_CURRENT
	attributes.set_base_value(&"hpMax", 275)
	_equal(vital.current_value, 275, "默认上限降低即时截断")
	attributes.get_vital(&"mana").set_current_value(25)
	attributes.set_base_value(&"mpMax", 200)
	_equal(attributes.get_vital_value(&"mana"), 25, "最大魔法与当前魔法分开")
	attributes.set_base_value(&"mpMax", 100)

func _verify_monster_isolation() -> void:
	var a := demo.session.spawn_entity("monsters", &"属性验收怪物") as BattleEntity
	var b := demo.session.spawn_entity("monsters", &"属性验收怪物") as BattleEntity
	a.attributes.set_level(8)
	a.attributes.set_equipment(&"weapon", (load("res://data/battle2d/equipment/attribute_test_weapon.tres") as BattleInventoryEquipment).battle_definition)
	a.apply_status_definition(&"attribute_test_buff")
	a.attributes.modify_vital(&"health", -30)
	a.attributes.get_vital(&"health").set_current_value(0)
	a.attributes.set_level(9)
	_equal(a.attributes.get_vital_value(&"health"), 0, "调高等级不能复活死亡实体")
	_equal(b.attributes.get_value(&"atk"), 26, "同配置怪物攻击独立")
	_equal(b.attributes.get_level(), 1, "同配置怪物等级独立")
	_equal(b.attributes.get_vital_value(&"health"), 275, "同配置怪物当前生命独立")
	_check(a.attributes.get_attribute(&"atk") != b.attributes.get_attribute(&"atk") and a.attributes.get_vital(&"health") != b.attributes.get_vital(&"health"), "怪物属性实例与Vital实例分别独占")
	_equal((load("res://data/attribute/progression/sunwukong.tres") as BattleAttributeProgression).growth_per_level[&"atk"], 5.25, "配置成长数据没有污染")
	var definition := demo.session.catalog.instantiate_definition("monsters", &"属性验收怪物") as BattleEntityDefinition
	definition.initial_level = 5
	var initial := BattleEntity.new()
	initial.initialize_battle(demo.session, &"test/initial-level", definition)
	demo.session.add_child(initial)
	_equal(initial.attributes.get_level(), 5, "配置初始等级通过统一入口装配")
	_equal(initial.attributes.get_value(&"hpMax"), 495, "初始非一级实体应用成长")
	_equal(initial.attributes.get_vital_value(&"health"), 495, "初始非一级实体生命按成长后上限填充")
	initial.queue_free()
	var invalid := definition.progression.duplicate(true) as BattleAttributeProgression
	invalid.growth_per_level[&"missing_attribute"] = 1
	_check(not invalid.is_configuration_valid({&"hpMax": true, &"mpMax": true, &"atk": true, &"phyDef": true}), "缺失成长属性在配置校验阶段拒绝")
#endregion
#region 实际伤害和编辑后的组合动画
func _verify_attack() -> void:
	var player: BattleEntity2D = demo.player
	var target: BattleEntity2D = demo.right_target
	player.position = Vector2(350, 650)
	player.animation.set_facing(1)
	target.position = Vector2(430, 650)
	attributes.set_base_value(&"atk", 80)
	_panel_matches()
	var context := {"damage_multiplier": 1.0}
	var expected: float = DamageCalculator.calculate_final_damage(target, player, context)
	var previous: float = target.attributes.get_vital_value(&"health")
	_check(player.try_activate_skill(&"sunwukong_attack1"), "基础属性改变后能释放原普攻")
	for tick in range(25):
		await get_tree().physics_frame
		demo.session.advance_physics(1.0 / 60.0)
	_equal(previous - target.attributes.get_vital_value(&"health"), expected, "下一次真实GAS攻击读取面板相同最终攻击")
	attributes.set_base_value(&"atk", 26)

func _verify_authored_animation() -> void:
	var adapter := demo.player.animation as SpineAnimationAdapter
	_check(adapter.last_error.is_empty() and adapter.get("_initialized"), "编辑过二段跳时长仍能初始化，角色不会消失")
	_check(adapter.play_action(&"jump_2", true), "组合语义动作可播放")
	adapter.advance_animation(0.28)
	var sprite := adapter.get_node("SpineVisual") as SpineSprite
	var entry := sprite.get_animation_state().get_track(0)
	_check(entry != null and entry.get_animation().get_name() == "jumpDown", "主AnimationPlayer能在第二关键帧切换Spine动作")
	_equal(entry.get_track_time(), 0.28 - 0.2667, "第二clip使用局部播放时间")
	_check(adapter.get_visual_bounds_global().size.x > 0.0 and adapter.get_visual_bounds_global().size.y > 0.0, "组合动作有可渲染姿态和附件")
#endregion
