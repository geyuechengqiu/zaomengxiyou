extends Node
#region 真实关卡、库存事务、原版动画注册点与生命周期回归
var scene: Node2D
var session: BattleSession
var player: BattleEntity2D
var hud: BattleOriginalHUD
var checks: int = 0
var failures: Array[String] = []
var executions: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func tick(delta: float) -> void:
	await get_tree().physics_frame
	session.advance_physics(delta)

func _ready() -> void:
	scene = load("res://examples/level_progression_demo.tscn").instantiate()
	scene.enable_player_controls = false
	add_child(scene)
	session = scene.session
	player = scene.player
	hud = scene.original_hud
	session.set_physics_process(false)
	scene.flow.stop()
	CoreSystem.event_bus.event_pushed.connect(_event)
	await tick(0.01)
	verify_inventory()
	await verify_ui()
	await verify_boss()
	CoreSystem.event_bus.event_pushed.disconnect(_event)
	scene.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS original battle UI: %d checks; inventory ownership/capacity/stack/lock/equipment/vitals/isolation, 103-frame CD registration, menu control/pause, original protection/wall/announcement, 59-frame execution/slow clock/cleanup and 36-frame gateway" % checks)
		get_tree().quit()
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)

func _event(id: String, payload: Array) -> void:
	if id == "battle.boss.execution_started" and payload.size() == 1 and payload[0].get("battle_id") == session.battle_id: executions += 1

func verify_inventory() -> void:
	var bag := player.inventory as OriginalInventory
	check(bag != null and bag.get_bag_items("equipment").size() == 3, "原版起始装备各有独立物品实例")
	var original := load("res://data/inventory/110101003.tres") as Equip
	var weapon := bag.get_bag_items("equipment")[2] as Equip
	check(weapon.item_id == &"110101003" and weapon != original, "原装备ID和定义/运行实例分离")
	check(bag.get_page_count("equipment") == 2 and hud.inventory_view.get_node("Grid").get_child_count() == 25, "原版25格分页与下一页锁格")
	var before := player.attributes.get_value(&"atk")
	bag.equip_item(weapon)
	check(player.attributes.get_value(&"atk") == before + 6 and bag.equip_slots.weapon[1] == weapon, "原封魔棒换装直接通知GAS属性和下一击")
	check(player.animation.get_skin_names().has(&"武器/weapon1") and hud.inventory_view.get_node("RolePortrait").get_skin_names().has(&"武器/weapon1"), "按原Resource8006穿装，战斗和背包预览同步weapon1外观")
	check(hud.inventory_view.get_node("Attributes/Value2").text == str(roundi(before + 6)), "背包属性面板同步最终攻击")
	bag.unequip_item(weapon)
	check(player.attributes.get_value(&"atk") == before and bag.get_bag_items("equipment").size() == 3, "卸下装备撤销加成，归还同一实例")
	check(not player.animation.get_skin_names().has(&"武器/weapon1"), "卸下恢复基础外观")
	var other := OriginalInventory.new()
	add_child(other)
	other.add_item(original)
	check(other.get_bag_items("equipment")[0] != weapon, "两个角色同原资源的装备互不污染")
	bag.toggle_lock(weapon)
	check(not bag.sell_item(weapon) and original.locked == false, "锁定后禁止出售，不污染定义资源")
	bag.toggle_lock(weapon)
	var spirit := bag.spirit
	check(bag.sell_item(weapon) and bag.spirit == spirit + 30, "确认出售移除封魔棒，原Unify.sellPrice按150×0.2结算灵魂")
	check(not bag.sell_item(weapon) and bag.get_bag_items("equipment").size() == 2, "已经卖出的旧引用不能重复出售")
	bag.add_item(original)
	var item := Item.new()
	item.item_id = &"test_material"
	item.name = "容量回归材料"
	item.category = Item.ITEM_TYPE.MATERIAL
	item.max_stack = 99
	item.quantity = 60
	bag.bag_capacities.material = 1
	bag.add_item(item)
	item.quantity = 39
	bag.add_item(item)
	check(bag.get_bag_items("material").size() == 1 and bag.get_bag_items("material")[0].quantity == 99 and item.quantity == 39, "满背包仍可合并剩余堆叠，不修改调用方资源数量")
	bag.add_item(item)
	check(bag.get_bag_items("material").size() == 1 and bag.get_bag_items("material")[0].quantity == 99, "容量不足拒绝整个事务，没有部分吞物品")
	bag.pack_items()
	check(bag.items.size() == 2000 and bag.get_bag_items("material")[0].quantity == 99, "四类各500格原版上限，整理保持容量和数量")
	check(bag.get_item(-1) == null and bag.get_item(10000) == null, "无效索引安全返回，不能覆盖末格")
	var potion := Item.new()
	potion.item_id = &"test_potion"
	potion.category = Item.ITEM_TYPE.CONSUMABLE
	potion.max_stack = 10
	potion.quantity = 2
	potion.original_data = {"isUse":1,"attributeT1":"hp","attributeV1":"10"}
	bag.add_item(potion)
	player.attributes.get_vital(&"health").set_current_value(100)
	bag.use_item(potion)
	check(player.attributes.get_vital_value(&"health") == 110 and bag.get_owned_item(potion).quantity == 1, "使用物品通过已有生命组件，成功后才扣数量")
	player.attributes.get_vital(&"health").set_current_value(player.attributes.get_value(&"hpMax"))
	bag.use_item(potion)
	check(bag.get_owned_item(potion).quantity == 1, "满生命不可使用且不丢失物品")
	var quote := bag.get_extension_quote("equipment",26)
	check(quote.costs[&"101018001"] == 1, "原OpenPack1026，解锁第26装备格需一个仙织革")
	check(not bag.extend_bag("equipment",26) and bag.bag_capacities.equipment == 25, "扩容材料不足不改容量")
	var token := Item.new()
	token.item_id = &"101018001"
	token.category = Item.ITEM_TYPE.CONSUMABLE
	token.max_stack = 99
	token.quantity = 3
	bag.add_item(token)
	check(bag.extend_bag("equipment",27) and bag.bag_capacities.equipment == 27 and bag.get_owned_item(token).quantity == 1, "跨格累计原消耗，一次确认原子解锁")
	check(not bag.extend_bag("equipment",29) and bag.bag_capacities.equipment == 27 and bag.get_owned_item(token).quantity == 1, "多格不足整笔失败，没有提前扣物品")
	other.free()

func verify_ui() -> void:
	var snapshot := player.attributes.get_snapshot()
	check(hud.get_node("Player/HPText").text == "%d/%d" % [snapshot.hp,snapshot.hpMax], "原角色生命条显示整数")
	check(hud.get_node("Player/Head").material != null, "原半径30头像裁切")
	check(hud.get_node("Skills").offset_top == -70 and hud.get_node("Skills/Slots").get_child_count() == 5, "原940x590技能条位置及四基础技能和火魔斩")
	check(not hud.get_node("Skills/WushuangKey").visible and hud.get_node("Skills/ItemKey0").text == "Q" and hud.get_node("Skills/ItemKey1").text == "E", "空怒气无双盘不常驻空格提示，原Q/E道具槽显示实际映射")
	var sprite := hud.get_node("Skills/Slots/Slot0/Cooldown") as AnimatedSprite2D
	check(sprite.sprite_frames.get_frame_count(&"cooldown") == 103 and sprite.position.is_equal_approx(Vector2(-8.35,-7.7)), "原103帧冷却遮罩和注册点，保留整帧画布")
	var cooldown := hud._cooldowns[0]
	cooldown.start_cooldown(hud._abilities[0])
	hud._process(0)
	check(sprite.visible and sprite.frame == 100, "刚释放技能使用原满冷却帧")
	var icon := hud.get_node("Skills/Slots/Slot0/Icon") as TextureRect
	check(icon.material == null, "冷却只用遮罩，不因CD/动作锁定把图标额外染暗")
	var mana := player.attributes.get_vital(&"mana")
	var original_mana := mana.current_value
	mana.set_current_value(0)
	hud._process(0)
	check(icon.material == hud.disabled_icon_material and icon.modulate == Color.WHITE, "魔法不足使用原灰度材质，保留图标亮度和透明度")
	mana.set_current_value(original_mana)
	hud._process(0)
	check(icon.material == null, "恢复魔法后立即恢复彩色图标")
	var status_data := GameplayStatusData.new()
	status_data.status_id = &"hud_icon_regression"
	status_data.duration = 1
	status_data.max_stacks = 3
	status_data.icon = icon.texture
	var status_instance := player.statuses.apply_status(status_data,player,2)
	var status_slot := hud.get_node("Player/StatusIcons/Status0") as Control
	check(status_slot.visible and status_slot.get_node("Icon").texture == status_instance.status_data.icon and status_slot.get_node("Count").text == "2", "状态小图与叠层由真实GAS状态立即刷新，读取独立运行定义")
	player.statuses.remove_status(status_data.status_id)
	check(not status_slot.visible and status_slot.get_node("Icon").texture == null, "状态移除清空图标，不留下旧图")
	hud.set_inventory_open(true)
	var elapsed := session.clock.elapsed
	await tick(10)
	check(session.clock.paused and session.clock.elapsed == elapsed and not player.operations.controller.has_control(), "背包暂停战斗并释放玩家控制权")
	hud.set_inventory_open(false)
	check(not session.clock.paused and not hud.inventory_view.visible, "关闭背包恢复时间和关卡")
	hud.show_notification("原版浮动提示")
	var notice := hud._last_notification
	hud._process(2.0)
	check(notice.visible and is_equal_approx(notice.position.y,-75), "CreateComponent1.5秒后启动AutoWarnBar最后一秒QuadOut上移100")
	hud._process(0.5)
	check(not notice.visible, "提示结束隐藏，无子窗口创建")
	hud.set_inventory_open(true)
	hud.show_notification("背包中的提示也会退出")
	hud._process(2.6)
	check(not hud._last_notification.visible and session.clock.paused, "UI提示独立于菜单暂停，且位于背包之上")
	hud.set_inventory_open(false)

func verify_boss() -> void:
	var boss := session.spawn_entity_2d("monsters", &"巨石灵君", Vector2(1000,1056))
	boss.ai_controller.enabled = false
	await tick(0.01)
	var feedback := session.presentation.get_node("BossFeedback") as BattleBossFeedback2D
	feedback.sound_enabled = false
	check(feedback.protect.texture_under.resource_path.ends_with("protect_background.png") and feedback.protect.texture_progress.resource_path.ends_with("protect_fill.png"), "原1326空保护条和1330填充对应正确")
	var profile := boss.ai_controller.boss_profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as BattleBossProfile
	profile.skills = [profile.skills[2]]
	boss.ai_controller.boss_profile = profile
	player.global_position = Vector2(1450,1056)
	boss.ai_controller.enabled = true
	await tick(0.01)
	boss.ai_controller.enabled = false
	await tick(0.75)
	var wall: BattleBossWorldObject2D
	for object in boss.ai_controller.objects.get_children():
		if object.active: wall = object; break
	check(wall != null, "第19帧生成实体石墙")
	if wall != null:
		check(wall.get_node("Visual/Sprite2D").get_parent().scale == Vector2(2,2), "图片与逐帧注册点同时缩放")
		check(wall.global_position.is_equal_approx(boss.global_position + Vector2(450,-10)), "墙壁原225,-5生成位置只换算一次")
	boss.cancel_skill()
	check(feedback.banner.visible, "动作开始后的播报不因打断提前消失")
	await tick(0.3)
	check(feedback.banner.visible and feedback.banner.position.x == 350 and feedback.banner.modulate.a == 1, "原技能播报到达x350/y80并停留")
	await tick(1.5)
	check(not feedback.banner.visible, "原2秒后7帧离场8帧清理")
	var stage := session.presentation.get_node("StageFeedback") as BattleStageFeedback
	var original_material := player.animation.material
	boss.attributes.get_vital(&"health").set_current_value(0)
	check(stage.is_execution_playing() and executions == 1, "Boss死亡触发一次原斩败")
	session.publish_event(&"battle.entity_died",boss)
	check(executions == 1, "重复死亡通知不重复斩败")
	check(stage.execution.player.get_animation(&"zs").track_get_key_count(0) == 59, "原斩败59帧30FPS保留完整时间轴")
	check(scene.get_node("BattleSession/Actors/Visuals").modulate == Color.BLACK and player.animation.material == stage.silhouette_material, "原地图黑场、角色白色剪影")
	session.request_hit_stop(0.1)
	await tick(0.1)
	check(session.clock.hit_stop_remaining == 0, "斩败抽帧期间命中停顿仍按真实时间结束")
	session.set_paused(true)
	var age := stage.execution.player.current_animation_position
	await tick(10)
	check(stage.execution.player.current_animation_position == age, "菜单暂停斩败，不跨越结尾")
	session.set_paused(false)
	await tick(2.0)
	check(not stage.is_execution_playing() and player.animation.material == original_material, "大delta跨末帧完成斩败，恢复材质和控制")
	var gateway := scene.get_node("BattleSession/Actors/FinalExit/Gateway") as OriginalUIAnimation2D
	check(not gateway.visible, "计划未完成，通关光圈隐藏")
	scene.get_node("BattleSession/Actors").set_final_exit_open(true)
	await tick(0.2)
	check(gateway.visible and gateway.active and gateway.player.get_animation(&"idle").track_get_key_count(0) == 36, "原1001出口36帧发光动画")
	scene.get_node("BattleSession/Actors").set_final_exit_open(false)
	check(not gateway.visible and not gateway.active, "关卡关闭出口停止光圈")
	session.clear_battle()
	check(not stage.is_execution_playing() and stage._actors.is_empty(), "离开关卡清理斩败材质及缓存")
#endregion
