extends Node
#region 真实会话/GAS结算、原版连击计数、战斗时钟和背包空格回归
var scene: Node2D
var session: BattleSession
var player: BattleEntity2D
var tracker: BattleHitComboTracker
var view: BattleHitComboView
var checks: int = 0
var failures: Array[String] = []
var last_settlement: Dictionary = {}
var nested_trigger: bool = false

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func tick(delta: float) -> void:
	await get_tree().physics_frame
	session.advance_physics(delta)

func _event(event_id: String, payload: Array) -> void:
	if event_id == "battle.damage.settled" and payload.size() == 1 and payload[0].get("battle_id") == session.battle_id:
		last_settlement = payload[0].duplicate()

func settle(source: Node, target: BattleEntity2D, normal: float, true_damage: float = 0, flags: Dictionary = {}) -> void:
	var info := DamageInfo.new(source)
	info.normal_damage = normal
	info.true_damage = true_damage
	info.final_damage = normal + true_damage
	info.is_dodged = flags.get("dodged", false)
	info.is_immune = flags.get("immune", false)
	session.publish_damage_result(info, target)

func _nested_hit(event_id: String, payload: Array) -> void:
	if nested_trigger and event_id == "battle.hit.effective" and payload[0].get("battle_id") == session.battle_id:
		nested_trigger = false
		session.apply_secondary_damage(player,player,1,&"periodic")

func _ready() -> void:
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	add_child(scene)
	session = scene.session
	player = scene.player
	tracker = session.hit_combo
	view = scene.original_hud.get_node("HitCombo")
	session.set_physics_process(false)
	scene.flow.stop()
	CoreSystem.event_bus.event_pushed.connect(_event)
	check(tracker != null and tracker.get_parent() == session and view.get_parent() == scene.original_hud, "连击逻辑与显示预置于共享会话/HUD，不挂玩家节点")
	check(not view.visible and tracker.get_count(player.entity_id) == 0, "开场无连击标志")
	check(view.position == Vector2(640,150) and view.get_node("Label").position == Vector2(192,0), "原版940x590画布位置与标志偏移")
	check(view.digit_textures.size() == 10 and view.digit_textures[0].get_size() == Vector2(56,62) and view.get_node("Label").texture.get_size() == Vector2(90,73), "原版数字十帧和连击贴图尺寸")
	var target := session.spawn_entity_2d("monsters", &"剑舞", Vector2(1200,1056), &"", false)
	assert(target != null, session.last_error)
	target.ai_controller.enabled = false
	await tick(0.01)
	var result := player.resolve_attack_hit(target, {"test_damage_random_1":true})
	check(float(result.get("normal_damage",0)) > 0 and tracker.get_count(player.entity_id) == 1, "真实技能伤害/GAS结算增加一次连击")
	check(view.visible and view.displayed_count == 1 and view.get_node("Digit0").texture == view.digit_textures[1] and not view.get_node("Digit1").visible, "首击显示原版1，个位在x144")
	CoreSystem.event_bus.push_event("battle.damage.settled", [last_settlement], true)
	session.publish_event(&"battle.attack.hit", player, target, result)
	check(tracker.get_count(player.entity_id) == 1, "重复结算广播和同击attack.hit不重复计数")
	player.resolve_attack_hit(target, {"test_damage_random_1":true})
	check(tracker.get_count(player.entity_id) == 2, "同一目标独立下一次命中增加连击")
	var other_target := session.spawn_entity_2d("monsters", &"剑舞", Vector2(1300,1056), &"", false)
	assert(other_target != null, session.last_error)
	other_target.ai_controller.enabled = false
	player.resolve_attack_hit(other_target, {"test_damage_random_1":true})
	check(tracker.get_count(player.entity_id) == 3, "同招多目标按各自结算增加连击")
	settle(player,target,0)
	settle(player,target,0,10)
	settle(player,target,10,0,{"dodged":true})
	settle(player,target,10,0,{"immune":true})
	settle(target,player,10)
	session.apply_secondary_damage(other_target,player,1,&"periodic")
	session.apply_secondary_damage(other_target,player,1,&"reflect")
	check(tracker.get_count(player.entity_id) == 3, "零普通伤害/纯真实伤害/闪避/免疫/怪物/持续伤害/反伤不增加玩家连击")
	var second_role := session.spawn_entity_2d("characters", &"孙悟空", Vector2(900,1056), &"", false)
	assert(second_role != null, session.last_error)
	settle(second_role,target,10)
	check(tracker.get_count(second_role.entity_id) == 1 and tracker.get_count(player.entity_id) == 3, "同配置不同角色连击独立")
	check(tracker.set_hit_owner(other_target.entity_id,player.entity_id), "宠物或召唤物可绑定角色归属")
	settle(other_target,target,10)
	check(tracker.get_count(player.entity_id) == 4 and tracker.get_count(second_role.entity_id) == 1, "召唤物命中计入主人，不污染其他角色")
	CoreSystem.event_bus.event_pushed.connect(_nested_hit)
	nested_trigger = true
	settle(player,target,1)
	CoreSystem.event_bus.event_pushed.disconnect(_nested_hit)
	check(tracker.get_count(player.entity_id) == 5 and tracker.get_pending_settlement_count() == 0, "有效命中回调先完成次生结算时，外层攻击仍计数且序号间隙及时清理")
	tracker.reset_chain(player.entity_id)
	for index in range(12): settle(player,target,1)
	check(view.displayed_count == 12 and view.get_node("Digit0").texture == view.digit_textures[2] and view.get_node("Digit1").texture == view.digit_textures[1] and view.get_node("Digit1").position.x == 96, "两位计数按原48像素间距右对齐")
	check(tracker.get_maximum(player.entity_id) == 12 and tracker.maximum_combo == 12, "角色及关卡记录最高连击")
	session.clock.hit_stop_remaining = 0
	await tick(1.0)
	check(tracker.get_count(player.entity_id) == 12, "1秒尚未超时")
	session.set_paused(true)
	await tick(10)
	check(view.visible and tracker.get_count(player.entity_id) == 12, "菜单暂停不消耗连击时间")
	session.set_paused(false)
	session.set_time_scale(0.5)
	await tick(0.4)
	check(tracker.get_count(player.entity_id) == 12, "慢动作按战斗时间计时")
	session.set_time_scale(1.0)
	session.request_hit_stop(0.5)
	await tick(0.5)
	check(tracker.get_count(player.entity_id) == 12, "命中停顿不消耗连击时间")
	settle(player,target,1)
	await tick(1.49)
	check(tracker.get_count(player.entity_id) == 13, "下一击刷新完整1.5秒窗口")
	await tick(0.011)
	check(not view.visible and tracker.get_count(player.entity_id) == 0 and tracker.get_maximum(player.entity_id) == 13, "超时隐藏并结束连击，保留最高连击")
	settle(player,target,1)
	check(view.displayed_count == 1, "结束后下一击从1重新计数")
	await tick(1.6)
	check(not view.visible, "低帧率跨越截止时间也正确结束")
	settle(player,target,1)
	session.publish_event(&"battle.entity.killed",target,player)
	check(not view.visible and tracker.get_count(player.entity_id) == 0, "角色死亡清理连击显示")
	view.set_count(12345)
	check(view.get_node("Digit3").texture == view.digit_textures[9] and view.get_node("Digit0").texture == view.digit_textures[9], "超四位安全显示，不访问越界数字节点")
	view.set_count(0)
	settle(player,target,1)
	verify_empty_slots()
	session.clear_battle()
	check(not view.visible and tracker.get_registered_role_count() == 0 and tracker.get_hit_owner_count() == 0 and tracker.get_pending_settlement_count() == 0, "离开关卡清理所有计数和归属")
	CoreSystem.event_bus.event_pushed.disconnect(_event)
	scene.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS hit combo: %d checks; original glyphs, real GAS hits, ownership, deduplication, timeout/pause/slow/hit-stop, maxima, lifecycle and empty inventory slots" % checks)
		get_tree().quit()
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)

func verify_empty_slots() -> void:
	var inventory_view: OriginalInventoryView = scene.original_hud.inventory_view
	scene.original_hud.set_inventory_open(true)
	var host := inventory_view.get_node("Grid").get_child(0) as Control
	var item := host.get_meta(&"item",null) as Item
	if item != null:
		inventory_view._slot_hover(0)
		check(inventory_view.get_node("Tooltip").visible, "物品悬停仍正常显示信息")
	inventory_view._render_slot(host,null,false)
	check(not host.has_meta(&"item"), "清空格子后Godot移除item元数据")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	inventory_view._slot_hover(0)
	inventory_view._slot_input(click,0)
	check(not inventory_view.get_node("Tooltip").visible and not inventory_view.get_node("Context").visible, "原有物品移除后悬停/点击空格隐藏信息，不读取缺失元数据")
	for index in range(25):
		var slot := inventory_view.get_node("Grid").get_child(index) as Control
		if not slot.get_meta(&"locked_slot",false) and not slot.has_meta(&"item"):
			inventory_view._slot_hover(index)
			inventory_view._slot_input(click,index)
	check(not inventory_view.get_node("Tooltip").visible, "连续悬停和点击全部空格无错误")
	inventory_view.refresh()
	scene.original_hud.set_inventory_open(false)
#endregion
