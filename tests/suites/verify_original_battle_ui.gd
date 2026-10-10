extends Node
#region 真实关卡、库存事务、原版动画注册点与生命周期回归
var scene: Node2D
var session: BattleSession
var player: BattleEntity2D
var hud: BattleOriginalHUD
var checks: int = 0
var failures: Array[String] = []
var executions: int = 0
var level_definition: BattleLevelDefinition

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
	hud = scene.original_hud
	session.set_physics_process(false)
	level_definition = scene.flow.definition
	scene.flow.stop()
	CoreSystem.event_bus.event_pushed.connect(_event)
	await tick(0.01)
	verify_inventory()
	await verify_ui()
	await verify_inventory_details()
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
	var next := hud.get_node("NextScreen") as Control
	check(next.global_position.is_equal_approx(hud.global_position + hud.size / 2), "前进动画注册点位于原版屏幕中心")
	check(next.anchor_left == 0.5 and next.anchor_right == 0.5 and next.anchor_top == 0.5 and next.anchor_bottom == 0.5, "前进提示使用随视口变化的居中锚点")
	check(scene.flow.start(level_definition), "前进提示验证初始化真实区域定义")
	hud._on_event("battle.region.exit_opened", [{"battle_id":session.battle_id,"region_id":session.level_instance.regions[0].definition.region_id}])
	check(next.get_node("Animation").active and next.get_node("Animation/Sprite2D").position == Vector2(0, -14), "区域通关播放前进动画并保留Flash原始注册点")
	hud._process(2.1)
	check(not next.get_node("Animation").visible, "前进动画完成后隐藏")
	scene.flow.stop()
	var bag_view := hud.inventory_view
	check(bag_view.get_node("Name").get_theme_font("font").resource_path.ends_with("ui_font.ttf"), "背包使用原方正粗圆字体")
	check(bag_view.get_node("Close") is TextureButton and bag_view.get_node("Wardrobe") is TextureButton and bag_view.get_node("Close").texture_pressed.resource_path.ends_with("bag_close_2.png"), "关闭与衣柜使用原三态按钮")
	check(bag_view.get_node("Attributes/Value0").horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER and bag_view.get_node("Equipment/Part0/Part").position.y == 19, "属性值居中且空装备名称在格内")
	var original_page := bag_view.page
	bag_view.get_node("PageButtons/Page1").pressed.emit()
	check(bag_view.page == 1 and bag_view.get_node("PageButtons/Page1/Text").text == "2", "圆形页码切到真实库存页")
	bag_view.page = original_page
	bag_view.refresh()
	var before_power: int = bag_view.get_node("FightPower").number
	var attack := player.attributes.get_attribute(&"atk").base_value
	player.attributes.set_base_value(&"atk", attack + 10)
	check(bag_view.get_node("FightPower").number == before_power + 120, "原攻击权重12，属性改变即时更新战斗力")
	player.attributes.set_base_value(&"atk", attack)
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
	check(sprite.visible and sprite.frame == 0, "刚释放技能使用原满冷却帧")
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

#region 原版背包细节：实际执行悬浮、对比、菜单和循环动画路径
func verify_inventory_details() -> void:
	var view := hud.inventory_view
	var bag := player.inventory as OriginalInventory
	hud.set_inventory_open(true)
	view.set_process(false)
	check(view.get_node("RolePortrait").scale == Vector2(0.5, 0.5), "独立背包人物按原版比例显示")
	var glow := view.get_node("PortraitGlow") as OriginalUIAnimation2D
	check(glow.active and glow.player.get_animation(&"bag_glow").track_get_key_count(0) == 30, "开包播放原30帧光效")
	glow.advance_effect(1.2)
	check(glow.active and glow.visible, "背包光效跨周期继续循环")
	var weapon := bag.get_bag_items("equipment")[2] as Equip
	var host := view.get_node("Grid/Slot2") as Control
	view._show_item_tip(weapon, host, false)
	var tooltip := view.get_node("Tooltip") as OriginalInventoryTooltip
	check(tooltip.visible and tooltip.get_node("Name").text == "封魔棒", "悬浮实际物品生成装备卡")
	check(tooltip.get_node("Body").text.contains("攻击: 6") and tooltip.get_node("Body").text.contains("未镶嵌宝石"), "装备卡读取GAS当前修正和原宝石孔")
	check(tooltip.get_node("Price").text == "价值: 30灵魂", "装备卡原出售价格")
	check(not view.get_node("ComparisonTooltip").visible, "未装备时布局单卡，无类型推断错误")
	bag.equip_item(weapon)
	bag.add_item(load("res://data/inventory/110101003.tres"))
	var spare := bag.get_bag_items("equipment")[2]
	view._show_item_tip(spare, host, false)
	check(view.get_node("ComparisonTooltip").visible and view.get_node("ComparisonTooltip/Equipped").visible, "同部位装备显示对比与装备中标记")
	check(is_equal_approx(tooltip.position.x-view.get_node("ComparisonTooltip").position.x, 257), "两装备卡按原间距排列")
	view._open_context(spare, false, host)
	check(view.get_node("Context").visible and not tooltip.visible, "点击物品关闭悬浮卡并打开菜单")
	check(view.get_node("Context/Use").visible and view.get_node("Context/Sell").visible and view.get_node("Context/Lock").visible and not view.get_node("Context/Close").visible and view.get_node("Context").size.y == 174 and not view.has_node("Context/Enhance") and not view.has_node("Context/Reroll"), "背包装备仅显示原三个操作按钮，成长交由独立面板")
	check(view.get_node("Context/Use/Caption").texture.resource_path.ends_with("bag_menu_text_1.png"), "装备按钮使用原文字帧")
	view._lock_selected()
	view._open_context(spare, false, host)
	check(view.get_node("Context/Sell").disabled and view.get_node("Context/Lock/Caption").texture.resource_path.ends_with("bag_menu_text_23.png"), "锁定禁售并显示解锁按钮")
	view._lock_selected()
	view._open_context(weapon, true, view.get_node("Equipment/Part1"))
	check(not view.get_node("Context").visible and bag.equip_slots["weapon"][1] == null and bag.get_bag_items("equipment").has(weapon), "点击已装备物品直接经插件卸下，不弹菜单")
	var name_input := view.get_node("Name") as LineEdit
	name_input.text = "悟空Abc123测试"
	name_input.text_changed.emit(name_input.text)
	check(bag.display_name == "悟空Abc123测试" and name_input.max_length == 15, "昵称输入中英文数字同步业务数据，最多15字符")
	bag.set_display_name("一二三四五六七八九十一二三四五六七八九十")
	check(bag.display_name.length() == 15 and name_input.text == bag.display_name, "插件入口同样限制Unicode字符，外部改名同步输入框")
	check(tooltip.get_node("Name").get_theme_constant("outline_size") == 2 and tooltip.get_node("Name").get_theme_color("font_outline_color") == Color.BLACK, "装备名称使用品质色和清晰黑色描边")
	var armor := bag.get_owned_item(load("res://data/inventory/110101001.tres"))
	check(armor.icon.get_image().get_data() == session.loot.catalog.get_definition(armor.item_id).icon.get_image().get_data() and (load("res://data/inventory/110101001.tres") as Item).icon.resource_path.ends_with("_ui.png"), "初始和掉落装备统一第二种原icon2图标")
	view.refresh()
	var armor_slot: Control
	for slot in view.get_node("Grid").get_children():
		if slot.has_meta(&"item") and slot.get_meta(&"item") == armor: armor_slot = slot
	check(armor_slot != null and armor_slot.get_node("Background").texture.resource_path.ends_with("slot_2.png"), "优秀装备使用原绿色品质边框而非普通边框")
	view.get_node("Context").hide()
	view._show_resistances()
	check(view.get_node("Resistances").visible and view.get_node("Resistances/Text").text.contains("火属性抗性"), "抗性悬浮使用实际最终属性")
	check(OriginalItemPresenter.get_resistance_text({&"waterResist":-30, &"fireResist":20}).contains("减免：17%"), "原正抗性减伤比例")
	check(OriginalItemPresenter.get_resistance_text({&"waterResist":-30}).contains("增加：30%"), "原负抗性增伤比例")
	view._hide_tip()
	var potion := Item.new()
	potion.item_id = &"details_potion"
	potion.name = "药水"
	potion.description = "生命恢复道具"
	potion.category = Item.ITEM_TYPE.CONSUMABLE
	potion.original_data = {"isUse":1, "price":10}
	bag.add_item(potion)
	view._show_item_tip(bag.get_owned_item(potion), host, false)
	check(tooltip.visible and not tooltip.get_node("LevelRow").visible and tooltip.get_node("Body").text.contains("生命恢复道具"), "道具卡隐藏装备强化行并展示说明")
	view._select_tab(3)
	check(view.get_node("FashionToggle").visible and not view.get_node("Wardrobe").visible, "时装开关与独立衣柜按钮分开")
	view.get_node("FashionToggle").pressed.emit()
	check(not bag.show_fashion, "时装按钮经过插件外观入口")
	view.get_node("FashionToggle").pressed.emit()
	view._select_tab(0)
	check(view.get_node("Wardrobe").visible and not view.get_node("FashionToggle").visible, "普通装备页恢复衣柜按钮")
	view._expand_number()
	for frame in range(35): await get_tree().process_frame
	check(view.get_node("PlayerNumber/Drawer").visible and is_equal_approx(view.get_node("PlayerNumber/Drawer").position.x, 43.1), "编号悬浮抽屉完成展开")
	view._collapse_number()
	for frame in range(15): await get_tree().process_frame
	check(not view.get_node("PlayerNumber/Drawer").visible, "编号离开完成收回")
	bag.unequip_item(weapon)
	view.set_process(true)
	hud.set_inventory_open(false)
	check(not glow.active and not glow.visible, "关包停止光效")
#endregion

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
