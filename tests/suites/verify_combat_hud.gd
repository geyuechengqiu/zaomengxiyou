extends Node
#region 原版底栏、关卡时钟和各怪物保护的真实关卡验收
var scene: Node2D
var hud: BattleOriginalHUD
var session: BattleSession
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func tick(delta: float) -> void:
	await get_tree().physics_frame
	for actor in session.get_entities():
		if actor is BattleEntity2D and actor.ai_controller != null: actor.ai_controller.enabled = false
	session.advance_physics(delta)
	hud.refresh_level_time()

func _ready() -> void:
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	add_child(scene)
	hud = scene.original_hud
	session = scene.session
	session.set_physics_process(false)
	var definition: BattleLevelDefinition = scene.flow.definition
	scene.flow.stop()
	check(hud.get_node("BattleTools").get_child_count() == 6, "原版主线战斗六个入口")
	for index in range(6):
		var button := hud.get_node("BattleTools").get_child(index) as TextureButton
		check(button.texture_normal != null and button.texture_hover != null and button.texture_pressed != null, "%s三个原按钮状态" % button.name)
		check(button.position == Vector2(285 + 63 * index,16) and button.size == Vector2(55,59), "%s原版位置及尺寸" % button.name)
	hud.get_node("BattleTools/BagButton").pressed.emit()
	check(hud.inventory_view.visible and session.clock.paused and not hud.is_module_open(), "点击原背包入口打开背包并暂停")
	hud.get_node("BattleTools/SkillButton").pressed.emit()
	check(not hud.inventory_view.visible and hud.is_module_open() and session.clock.paused and hud.get_node("SkillPanel/Main/Rows/S1101030/Name").text.contains("火"), "技能入口打开原版技能面板，只保留一个模块")
	hud.get_node("BattleTools/SettingsButton").pressed.emit()
	check(scene.menu.visible and not hud.is_module_open() and session.clock.paused, "设置入口接入真实改键菜单")
	scene.menu.set_open(false)
	check(not session.clock.paused, "最后一个菜单关闭恢复战斗")
	hud.get_node("BattleTools/PetButton").pressed.emit()
	check(not hud.is_module_open() and not session.clock.paused and hud._last_notification.get_node("Text").text == "你还没有灵宠", "未拥有灵宠时沿用原提示")
	hud.get_node("BattleTools/MagicButton").pressed.emit()
	check(hud.is_module_open() and hud.get_node("ModulePanel/Text").text.contains("尚未装备法宝"), "法宝入口读取真实装备槽")
	hud.get_node("ModulePanel/Close").pressed.emit()
	hud.get_node("BattleTools/HeartButton").pressed.emit()
	check(hud.is_module_open() and session.clock.paused, "心法入口不会泄露角色操作")
	hud.set_module_open(false)
	check(scene.flow.start(definition), "重新开始真实出生计划计时")
	await tick(61.9)
	check(hud.get_node("LevelTimer/Time").text == "01:01", "计时秒截断与两位分秒")
	hud.set_inventory_open(true)
	await tick(10)
	check(hud.get_node("LevelTimer/Time").text == "01:01", "背包暂停不消耗关卡时间")
	hud.set_inventory_open(false)
	await tick(0.2)
	check(hud.get_node("LevelTimer/Time").text == "01:02", "关闭背包时间连续恢复")
	scene.flow.stop()
	for id in [&"剑舞", &"驭兽使", &"复苏容器"]:
		var monster := session.spawn_entity_2d("monsters", id, Vector2(1800,1056))
		monster.ai_controller.enabled = false
		monster._finish_spawn_appearance()
		check(monster.protection.maximum == 100000 and not monster.protection.profile.protection_action_enabled, "%s原100000阈值，无保护技" % id)
		monster.protection.register_hit({"original_skill_id":1101010,"protection_parameters":{"protectPoint":100000}},1,100)
		check(monster.protection.score == 0 and not monster.protection.active and monster.protection.hit_counts.is_empty() and not TagManager.has_tag(monster,&"state.invulnerable"), "%s满值只清计数，不伪造无敌" % id)
		check(not monster.feedback.get_node("ProtectionBar").visible, "%s不显示头顶调试保护条" % id)
		session.despawn_entity(monster.entity_id)
	var boss := session.spawn_entity_2d("monsters", &"巨石灵君", Vector2(2400,1056))
	boss.ai_controller.enabled = false
	boss._finish_spawn_appearance()
	boss.apply_status_definition(&"stun",scene.player)
	boss.apply_status_definition(&"slow",scene.player)
	check(TagManager.has_tag(boss, &"state.stunned"), "保护验收先真实施加眩晕")
	boss.protection.register_hit({"original_skill_id":1101010,"protection_parameters":{"protectPoint":25000}},1,1167)
	boss.protection.refresh_visual()
	check(boss.protection.active and not TagManager.has_tag(boss, &"state.stunned") and TagManager.has_tag(boss, &"state.invulnerable"), "25000阈值净化并施加原无敌Buff")
	check(is_equal_approx(boss.animation.modulate.a,0.5), "原无敌透明度一半")
	check(boss.apply_status_definition(&"stun",scene.player) == null, "两秒保护期间免疫新减益")
	await tick(1.9)
	check(not boss.protection.active and TagManager.has_tag(boss, &"state.invulnerable"), "原单次保护动作结束后，无敌Buff仍独立持续两秒")
	await tick(0.11)
	check(not boss.protection.active and not TagManager.has_tag(boss, &"state.invulnerable") and is_equal_approx(boss.animation.modulate.a,1), "两秒结束恢复透明度和受击")
	var stun := boss.apply_status_definition(&"stun",scene.player)
	check(stun != null, "保护结束可再次被控制")
	if stun != null: boss.statuses.remove_instance(stun, &"test_reset")
	boss.statuses.apply_status(load("res://data/buffs/debuff_immunity.tres"),boss)
	check(not TagManager.has_tag(boss,&"state.invulnerable") and TagManager.has_tag(boss,&"state.debuff_immune"), "减益免疫独立于无敌状态")
	var damage := session.apply_secondary_damage(boss,scene.player,10,&"test")
	check(damage.actual_hp_loss == 10 and boss.apply_status_definition(&"stun",scene.player) == null, "单独减益免疫不免伤，但拒绝眩晕")
	scene.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS combat HUD: %d checks; original six tools/state textures/layout, modal ownership, real inventory/settings/GAS data, level timer/pause, three ordinary thresholds, Boss cleanse/two-second immunity/alpha/restoration" % checks)
		get_tree().quit()
	else:
		for message in failures: push_error(message)
		get_tree().quit(1)
#endregion
