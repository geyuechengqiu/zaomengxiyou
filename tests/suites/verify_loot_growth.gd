extends Node
#region 阶段14：真实关卡、物品事务与伤害回归
var scene: Node2D
var session: BattleSession
var player: BattleEntity2D
var bag: OriginalInventory
var loot: BattleLootManager2D
var failures: Array[String] = []
var checks: int = 0
var changes: int = 0
var reward_events: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func tick(delta: float) -> void:
	await get_tree().physics_frame
	session.advance_physics(delta)

func _ready() -> void:
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	add_child(scene)
	session = scene.session
	player = scene.player
	bag = player.inventory as OriginalInventory
	loot = session.loot
	session.set_physics_process(false)
	scene.flow.stop()
	player.global_position = Vector2(420, 1056)
	for entity in session.get_entities():
		if entity is BattleEntity2D and entity.ai_controller != null: entity.ai_controller.enabled = false
	CoreSystem.event_bus.event_pushed.connect(_event)
	bag.equipment_changed.connect(func(_data): changes += 1)
	for _frame in range(8): await tick(1.0 / 60.0)
	check(loot != null and loot.get_parent() == session and loot.get_child_count() == 0, "公共掉落预置且不挂载角色，大量灵魂无需逐个创建节点")
	verify_instances()
	await verify_growth_and_damage()
	await verify_rewards_and_pickup()
	CoreSystem.event_bus.event_pushed.disconnect(_event)
	session.clear_battle()
	check(loot.drops.is_empty() and loot.souls.is_empty() and loot.awarded.is_empty(), "离开关卡清理所有掉落、灵魂和发奖记录")
	check(scene.original_hud.get_node("PickupEffects").flights.is_empty(), "离场同时清理HUD拾取飞行，不残留已入库图标")
	scene.free()
	await get_tree().process_frame
	if failures.is_empty(): print("PASS stage 14 loot/growth: %d checks; immutable definitions/UID/save state, growth costs/restrictions/reroll/sets, GAS/UI/actual hit/skins, original EXP/spirit/soul/pickups, capacity retry, death hide/pause/cleanup" % checks); get_tree().quit()
	else:
		for message in failures: push_error(message)
		get_tree().quit(1)

func _event(id: String, payload: Array) -> void:
	if id == "battle.loot.rewarded" and payload.size() == 1 and payload[0].get("battle_id") == session.battle_id: reward_events += 1

func verify_instances() -> void:
	var definition := load("res://data/inventory/110101003.tres") as Item
	var item := bag.get_owned_item(definition)
	var peer := OriginalInventory.new()
	add_child(peer)
	peer.add_item(definition)
	var other := peer.get_owned_item(definition)
	check(item != definition and item.definition == definition and item.runtime != null and definition.runtime == null, "物品资源只保存定义，独立状态保存于InventoryItemState")
	check(item.runtime.unique_id.length() == 32 and item.runtime.unique_id != other.runtime.unique_id, "跨角色唯一ID，非每个背包从1开始的编号")
	var saved := item.get_save_data()
	var state := InventoryItemState.from_dictionary(saved.state)
	state.additional_attributes["atk"] = 99
	check(state.unique_id == item.runtime.unique_id and not item.runtime.additional_attributes.has("atk"), "实例可保存且恢复状态不共享字典")
	check(not peer.try_add_item(item), "其他背包不能重复接收已持有实例")
	peer.free()

func add_material(id: StringName, count: int) -> Item:
	var item := Item.new()
	item.item_id = id
	item.name = String(id)
	item.category = Item.ITEM_TYPE.MATERIAL
	item.max_stack = 999
	item.quantity = count
	bag.add_item(item)
	return bag.get_owned_item(item)

func verify_growth_and_damage() -> void:
	var definition := load("res://data/inventory/110101003.tres") as Item
	var weapon := bag.get_owned_item(definition) as Equip
	var armor := bag.get_owned_item(load("res://data/inventory/110101001.tres")) as Equip
	var helmet := bag.get_owned_item(load("res://data/inventory/110101002.tres")) as Equip
	var original_attack := player.attributes.get_value(&"atk")
	bag.equip_item(weapon)
	var position := player.position
	var duration := player.animation.get_action_duration(&"attack_1")
	var context := {"ability_id":&"sunwukong_attack1", "sample_time":0.2, "source_fps":30, "hit_index":1}
	var hitbox := player.get_attack_rect_local(context)
	check(player.attributes.get_value(&"atk") == original_attack + 6 and scene.original_hud.inventory_view.get_node("Attributes/Value2").text == str(int(original_attack + 6)), "穿戴同步GAS与背包面板")
	bag.grant_spirit(100)
	var currency := bag.spirit
	check(not bag.apply_growth(weapon, &"enhance") and bag.spirit == currency and weapon.runtime.enhancement_level == 0, "缺材料拒绝整个强化事务")
	var stone := add_material(&"101005001", 4)
	var change_before := changes
	check(bag.apply_growth(weapon, &"enhance"), "使用原EquRefine2001强化封魔棒")
	check(changes == change_before + 1 and stone.quantity == 3 and bag.spirit == currency - 4 and weapon.runtime.enhancement_level == 1, "一次强化一次统一通知，扣4灵魂与1颗强化石")
	check(player.attributes.get_value(&"atk") == original_attack + 13 and scene.original_hud.inventory_view.get_node("Attributes/Value2").text == str(int(original_attack + 13)), "原ItemVo强化7.4四舍五入为7，面板与GAS同步")
	check(definition.runtime == null and definition.battle_definition.attribute_modifiers[0].value == 6, "强化没有污染共享定义")
	check(bag.set_item_additions(weapon, {"atk":5}) and bag.set_item_additions(weapon, {"atk":2}) and bag.set_item_additions(weapon, {"atk":3}, true), "附加属性与随机词条分别存入实例")
	check(player.attributes.get_value(&"atk") == original_attack + 18, "替换附加属性不累计旧来源，词条与强化同时生效")
	var set_definition := InventoryEquipmentSet.new()
	set_definition.set_id = &"verification_set"
	set_definition.item_ids.assign([weapon.item_id, armor.item_id, helmet.item_id])
	set_definition.bonuses.assign([{"pieces":2,"attributes":{"atk":10}}, {"pieces":3,"attributes":{"phyDef":8}}])
	bag.equipment_sets.append(set_definition)
	bag.equip_item(armor)
	check(player.attributes.get_value(&"atk") == original_attack + 28 and bag.get_active_set_bonuses().size() == 1, "两件套触发一个门槛")
	bag.equip_item(helmet)
	check(bag.get_active_set_bonuses().size() == 2, "三件套累计激活两个门槛")
	bag.unequip_item(armor)
	check(bag.get_active_set_bonuses().size() == 1, "卸下仅移除已不满足的三件套门槛")
	bag.unequip_item(helmet)
	check(bag.get_active_set_bonuses().is_empty() and player.attributes.get_value(&"atk") == original_attack + 18, "不足两件时套装不残留")
	bag.equipment_sets.clear()
	check(duration > 0 and player.position == position and player.animation.get_action_duration(&"attack_1") == duration and player.animation.get_skin_names().has(&"武器/weapon1"), "换装不改变位置、动作时长，皮肤独立更新")
	check(hitbox.has_area() and player.get_attack_rect_local(context) == hitbox, "换装没有更改技能攻击框大小或注册点")
	player.animation.set_facing(-1)
	var mirrored := player.get_attack_rect_local(context)
	check(mirrored.size == hitbox.size and is_equal_approx(mirrored.get_center().x, -hitbox.get_center().x), "换装后攻击框仍按角色朝向正确镜像")
	player.animation.set_facing(1)
	var target := session.spawn_entity_2d("monsters", &"剑舞", player.global_position + Vector2(90, 0))
	target.ai_controller.enabled = false
	target.attributes.set_base_value(&"hpMax", 1000)
	target.attributes.get_vital(&"health").set_current_value(1000)
	session.damage_strategy = SimpleDamageLogic.new()
	var expected: float = DamageCalculator.calculate_final_damage(target, player, {"damage_multiplier":1.0})
	player.animation.set_facing(1)
	check(player.try_activate_skill(&"sunwukong_attack1"), "强化装备后能实际发动普攻")
	for _frame in range(30): await tick(1.0 / 60.0)
	check(is_equal_approx(1000 - target.attributes.get_vital_value(&"health"), expected), "下一次真实GAS命中使用强化、词条与附加属性的最终攻击")
	session.despawn_entity(target.entity_id)
	bag.unequip_item(weapon)
	check(player.attributes.get_value(&"atk") == original_attack, "卸下清理所有装备层，无强化、词条、附加或套装残留")
	check(not player.animation.get_skin_names().has(&"武器/weapon1"), "卸下恢复基础皮肤")
	var quote_second := bag.get_growth_quote(weapon, &"enhance")
	check(int(quote_second.spirit) == 5 and bag.get_context_actions(weapon, false).size() == 3, "第二级保留原成本入口，背包点击菜单不包含强化或洗练")
	check(bag.apply_growth(weapon, &"enhance") and weapon.runtime.enhancement_level == 2 and stone.quantity == 2, "独立成长面板可复用同一原子成长入口")
	check(not bag.apply_growth(weapon, &"reroll"), "封魔棒原isReset0明确禁止洗练")
	var reset_id := StringName(bag.growth_rules.data.reset_sample)
	var reset_definition := loot.catalog.get_definition(reset_id)
	bag.add_item(reset_definition)
	var reset_item := bag.get_owned_item(reset_definition)
	var quote := bag.get_growth_quote(reset_item, &"reroll")
	for group: Dictionary in quote.groups: add_material(StringName(group.ids[0]), int(group.count))
	var uid := reset_item.runtime.unique_id
	check(bag.apply_growth(reset_item, &"reroll") and reset_item.runtime.unique_id == uid and not reset_item.runtime.rolled_attributes.is_empty(), "真实允许洗练的原装备消耗EquReset材料，重抽属性但保留UID")
	for id in reset_item.runtime.rolled_attributes:
		var range_values := String(reset_item.original_data[id]).split(";")
		check(float(reset_item.runtime.rolled_attributes[id]) >= float(range_values[0]) and float(reset_item.runtime.rolled_attributes[id]) <= float(range_values[1]), "洗练结果落在原Equipment属性区间")
	var restriction := definition.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as Equip
	restriction.item_id = &"verification_restriction"
	restriction.original_data.roleConditions = 2
	bag.add_item(restriction)
	bag.equip_item(restriction)
	check(bag.equip_slots.weapon[1] == null, "角色装备限制正确拒绝")
	bag.get_owned_item(restriction).original_data.roleConditions = 1
	bag.get_owned_item(restriction).original_data.userLevel = 999
	bag.equip_item(restriction)
	check(bag.equip_slots.weapon[1] == null, "等级装备限制正确拒绝")
#endregion

#region 原始掉落、立即奖励、纯表现飞行和死亡清理
func verify_rewards_and_pickup() -> void:
	loot.clear_loot()
	player.attributes.set_experience(0)
	var spirit := bag.spirit
	var xp := player.attributes.get_value(&"exp")
	var monster := session.spawn_entity_2d("monsters", &"剑舞", player.global_position + Vector2(150, 0))
	monster.ai_controller.enabled = false
	var events := reward_events
	monster.attributes.get_vital(&"health").set_current_value(0)
	await tick(1.0 / 60.0)
	check(bag.spirit == spirit + 8 and player.attributes.get_value(&"exp") == xp + 6 and reward_events == events + 1, "普通怪死亡按原Drop1立即结算8灵魂6经验，只执行一次")
	check(loot.souls.size() == 1 and loot.spirit_texture.resource_path.ends_with("spirit_drop.png"), "每次灵魂奖励创建一次使用原素材的飞行表现")
	var initial_position: Vector2 = loot.souls[0].position
	session.set_paused(true)
	await tick(1)
	check(loot.souls[0].position == initial_position, "暂停不推进灵魂飞行或地面掉落")
	session.set_paused(false)
	for _frame in range(12): await tick(0.25)
	check(not monster.visible and monster.collision_layer == 0 and not monster.is_alive(), "死亡动画后怪物隐藏并停用物理碰撞，不留尸体")
	check(bag.spirit == spirit + 8 and player.attributes.get_value(&"exp") == xp + 6, "灵魂抵达玩家不会再次发奖")
	check(loot.souls.is_empty(), "低帧率飞行能抵达并清理所有拖尾")
	monster.publish_battle_event(&"battle.entity_died")
	await tick(0.1)
	check(reward_events == events + 1, "重复死亡事件不能重复发奖")
	loot.drops.clear()
	var count := bag.get_bag_items("equipment").size()
	var pickup_notifications: Array[String] = []
	bag.operation_rejected.connect(func(message): pickup_notifications.append(message))
	bag.operation_completed.connect(func(message): pickup_notifications.append(message))
	var feedback := scene.original_hud.get_node("PickupEffects") as BattlePickupFeedback
	feedback.set_process(false)
	feedback.clear_effects()
	bag.bag_capacities.equipment = count
	check(loot.spawn_item(&"110101001", player.global_position, player), "生成原版Boss掉落装备实例")
	check(not loot.pickup_drop(0, player) and loot.drops.size() == 1, "背包满时保留掉落物，无吞装备")
	check(feedback.flights.is_empty(), "拒绝拾取时不生成飞入背包动画")
	var uid: String = loot.drops[0].item.runtime.unique_id
	bag.bag_capacities.equipment = 25
	check(loot.pickup_drop(0, player) and loot.drops.is_empty(), "释放容量后同一掉落可以重新拾取")
	check(pickup_notifications.is_empty(), "拾取成功和容量满重试均不弹问题提示")
	check(feedback.flights.size() == 1 and feedback.get_child_count() == 0, "装备入库后生成一次共享HUD飞行，无逐物品节点")
	var flight: Dictionary = feedback.flights[0].duplicate()
	check(is_equal_approx(float(flight.duration), Vector2(flight.from).distance_to(flight.to) / 200.0), "原FlyItemEntity按屏幕距离除200确定时长")
	feedback.advance_effects(float(flight.duration) / 2.0)
	check(Vector2(feedback.flights[0].position).is_equal_approx(Vector2(flight.from).lerp(flight.to, 0.875)) and feedback.flights[0].size == flight.size, "原Cubic.easeOut中点走完87.5%，大小不变")
	check(loot.get_quality_glow_index(loot.catalog.get_definition(&"110101001")) == 1 and loot.quality_glows[1].get_size() == Vector2(94,94) and loot.quality_glow_pivots[1] == Vector2(-47,-47), "优秀装备匹配原品质光晕与94像素画布注册点")
	check(loot.get_quality_glow_index(loot.catalog.get_definition(&"101014001")) == -1, "补给品不误加装备品质光晕")
	feedback.advance_effects(float(flight.duration))
	check(feedback.flights.is_empty(), "飞入背包后清理表现，不卡在图标终点")
	var found := false
	for item in bag.get_bag_items("equipment"):
		if item.runtime.unique_id == uid: found = true
	check(found and not loot.pickup_drop(0, player), "拾取保留随机属性与UID，旧索引不能重复入库")
	var health := player.attributes.get_vital(&"health")
	var mana := player.attributes.get_vital(&"mana")
	health.set_current_value(health.get_max_value())
	mana.set_current_value(1)
	loot.spawn_item(&"101014001", player.global_position, player)
	check(not loot.pickup_drop(0, player) and loot.drops.size() == 1 and feedback.flights.is_empty(), "生命满即保留回血补给，即使魔法未满也不拾取")
	await tick(0.1)
	check(loot.drops.size() == 1, "持续接触满值补给也不会消耗")
	player.attributes.get_vital(&"health").set_current_value(10)
	var hp := player.attributes.get_vital_value(&"health")
	check(loot.pickup_drop(0, player) and player.attributes.get_vital_value(&"health") == hp + floorf(player.attributes.get_value(&"hpMax") * 0.25), "原萝卜按最大生命25%恢复，不进入普通背包")
	check(feedback.flights.is_empty(), "回血补给直接恢复生命，不飞入背包")
	mana.set_current_value(mana.get_max_value())
	loot.spawn_item(&"101014003", player.global_position, player)
	check(not loot.pickup_drop(0, player) and loot.drops.size() == 1, "魔法满保留回魔补给，即使生命未满也不拾取")
	# 固定接触状态，隔离随机掉落横向抛出后离开接触范围的情况。
	loot.drops[0].grounded = true
	loot.drops[0].position = player.get_body_rect_global().get_center()
	await tick(0.1)
	check(loot.drops.size() == 1 and loot.drops[0].retry == 0.0, "满值补给不进入满背包的一秒重试，继续接触时缺值即可拾取")
	mana.set_current_value(1)
	await tick(0.1)
	check(mana.current_value > 1 and loot.drops.is_empty(), "魔法下降后接触中的同一补给自动拾取并按最大魔法恢复")
	var before_equipment := bag.get_bag_items("equipment").size()
	loot.spawn_item(&"110001003", player.global_position, player)
	await tick(0.1)
	check(loot.drops.is_empty() and bag.get_bag_items("equipment").size() == before_equipment + 1, "真实物理接触自动拾取装备，非仅调用测试拾取方法")
	var simple_weapon: BattleInventoryEquipment
	for item in bag.get_bag_items("equipment"):
		if item.item_id == &"110001003": simple_weapon = item as BattleInventoryEquipment
	bag.equip_item(simple_weapon)
	check(player.animation.get_skin_names().has(&"武器/weapon0"), "原普通行者棒Resource8003映射weapon0，不套用封魔棒weapon1")
	bag.unequip_item(simple_weapon)
	loot.spawn_item(&"101002000", player.global_position + Vector2(800, 0), player)
	for _frame in range(5): await tick(0.2)
	var grass_found := false
	for item in bag.get_bag_items("material"):
		if item.item_id == &"101002000": grass_found = true
	check(loot.drops.is_empty() and grass_found, "原止血草落地后按isAutoPick远距离自动拾取")
	var previous_level := player.attributes.current_level
	player.attributes.get_vital(&"health").set_current_value(10)
	for _index in range(20):
		var extra := session.spawn_entity_2d("monsters", &"剑舞", player.global_position + Vector2(500, 0))
		extra.ai_controller.enabled = false
		extra.attributes.get_vital(&"health").set_current_value(0)
	await tick(0.25)
	check(player.attributes.current_level == previous_level + 1 and player.attributes.get_value(&"exp") == 16, "20次击杀所得120经验走原升级入口，扣110经验后剩16")
	check(player.attributes.get_vital_value(&"health") == player.attributes.get_value(&"hpMax"), "击杀升级同步成长属性并按原流程回满生命")
	check(loot.get_child_count() == 0 and loot.souls.size() == 20, "同时20次死亡使用共享灵魂绘制，不动态追加节点")
	loot.drops.clear()
	var boss := session.spawn_entity_2d("monsters", &"巨石灵君", player.global_position + Vector2(350, 0))
	boss.ai_controller.enabled = false
	spirit = bag.spirit
	xp = player.attributes.get_value(&"exp")
	boss.attributes.get_vital(&"health").set_current_value(0)
	await tick(1.0 / 60.0)
	check(bag.spirit == spirit + 57 and player.attributes.get_value(&"exp") == xp + 44 and loot.drops.size() == 1 and loot.drops[0].item.item_id == &"110101001", "Boss按原Drop1001发57灵魂44经验且必掉封煞甲：灵魂%d/%d，经验%d/%d，地面%d" % [bag.spirit, spirit + 57, player.attributes.get_value(&"exp"), xp + 44, loot.drops.size()])
	check(session.presentation.get_node("StageFeedback").is_execution_playing(), "Boss死亡保留原斩败播报")
#endregion
