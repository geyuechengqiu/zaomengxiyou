extends Node
var checks: int = 0
var failures: Array[String] = []
var scene: Node2D
var player: BattleEntity2D
var effect: BattleSuperArmorEffect2D

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func tick(delta: float) -> void:
	await get_tree().physics_frame
	scene.session.advance_physics(delta)

func _ready() -> void:
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	add_child(scene)
	scene.session.set_physics_process(false)
	scene.flow.stop()
	player = scene.player
	player.global_position = Vector2(800, 1056)
	effect = player.animation.get_node("SuperArmorEffect") as BattleSuperArmorEffect2D
	await tick(0.1)
	check(not effect.active and not effect.outline.visible and effect.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "无霸体时不显示、不渲染快照")
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/effects/super_armor/original_source.json"))
	check(original.colors == ["ff0000", "ffff00"] and original.blur == [5.0, 5.0] and original.strength == 3, "原红黄描边、模糊5和强度3")
	check(original.logic.size() == 3 and original.cycle_frames == 22, "保留三个原逻辑来源和含端点的22帧周期")
	check(BattleSuperArmorEffect2D.original_color(0) == Color.RED and BattleSuperArmorEffect2D.original_color(10) == Color.YELLOW and BattleSuperArmorEffect2D.original_color(11) == Color.YELLOW and BattleSuperArmorEffect2D.original_color(21) == Color.RED, "颜色端点与反向重启顺序一致")
	check(BattleSuperArmorEffect2D.original_color(1) == Color8(255,25,0) and BattleSuperArmorEffect2D.original_color(12) == Color8(255,230,0), "原AS3整数中间步骤截断，不替换为连续渐变")
	var source_material: Material = effect._source.material
	var source_tint: Color = effect._source.modulate
	var nodes := effect.get_child_count()
	var buff := (load("res://data/buffs/super_armor.tres") as GameplayStatusData).duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as GameplayStatusData
	buff.duration = 5
	player.statuses.apply_status(buff, player)
	check(effect.active and effect.outline.visible and player.reactions.is_armored(player), "真实GAS霸体与描边同时生效")
	await tick(1.0/30.0)
	check(effect.current_color == Color.RED, "原第一帧为红色")
	for index in range(10): await tick(1.0/30.0)
	check(effect.current_color == Color.YELLOW, "原第11帧到达黄色")
	var elapsed := effect.elapsed
	var samples := effect.mirror.capture_count
	scene.session.set_paused(true)
	await tick(1)
	check(effect.elapsed == elapsed and effect.mirror.capture_count == samples, "暂停不推进颜色或轮廓快照")
	scene.session.set_paused(false)
	scene.session.set_time_scale(0.5)
	await tick(0.1)
	check(is_equal_approx(effect.elapsed - elapsed, 0.05), "慢动作只缩放一次表现时间")
	scene.session.set_time_scale(1)
	player.animation.set_facing(-1)
	effect.advance_effect(0)
	check(effect.mirror.get_skeleton().get_scale_x() == -1 and effect.outline.offset == -effect.capture_origin, "镜像保持脚底、武器和轮廓位置")
	var duration := player.animation.get_action_duration(&"idle")
	check(player.animation.set_equipment_skin(&"armor", &"衣服/armor1"), "换装走原外观入口")
	effect.advance_effect(0)
	check(effect._skins == player.animation.get_skin_names() and player.animation.get_action_duration(&"idle") == duration, "描边跟随换装，不改变动作时长")
	player.animation.set_equipment_skin(&"armor", &"")
	effect._source.modulate = Color(1,0.5,0.5,0.7)
	player.animation.modulate.a = 0.5
	effect.advance_effect(0.1)
	check(effect._source.modulate == Color(1,0.5,0.5,0.7) and player.animation.modulate.a == 0.5 and effect._source.material == source_material, "受击染色、保护透明度和源材质不被描边覆盖")
	effect._source.modulate = source_tint
	player.animation.modulate.a = 1
	check(effect.get_child_count() == nodes and effect.outline.material != effect._source.material, "使用预置节点和独立材质")
	player.wushuang.add_rage(10000)
	check(player.try_activate_skill(&"sunwukong_wushuang"), "真实无双入口可与霸体同存")
	await tick(0.1)
	var wushuang := player.animation.get_node("WushuangEffect") as BattleWushuangEffect2D
	check(not effect.active and wushuang.active and wushuang.halo.visible and player.reactions.is_armored(player), "原无双红光优先，隐藏描边但不撤销霸体规则")
	player.statuses.remove_status(&"normal_wushuang_visual")
	await tick(0.01)
	check(effect.active and not wushuang.active, "无双结束后仍在持续的霸体描边恢复")
	player.statuses.remove_status(buff.status_id)
	await tick(0.01)
	check(not effect.active and not effect.outline.visible, "Buff移除不残留描边")
	player.super_armor = true
	effect.advance_effect(0.1)
	check(effect.active, "常驻霸体使用相同受击裁决")
	player.super_armor = false
	player.action_state.active_rules["super_armor"] = true
	effect.advance_effect(0.1)
	check(effect.active, "技能动作霸体使用相同受击裁决")
	player.action_state.active_rules["super_armor"] = false
	effect.advance_effect(0.1)
	check(not effect.active, "动作霸体结束时清理")
	player.super_armor = true
	effect.enabled = false
	effect.advance_effect(0.1)
	check(not effect.active and player.reactions.is_armored(player), "可关闭showBatiEff表现，战斗规则仍有效")
	effect.enabled = true
	for id in [&"剑舞", &"驭兽使", &"复苏容器", &"巨石灵君"]:
		var monster: BattleEntity2D = scene.session.spawn_entity_2d("monsters", id)
		check(monster != null, "%s可通过真实关卡索引生成" % id)
		if monster == null: continue
		monster.ai_controller.enabled = false
		var other := monster.animation.get_node("SuperArmorEffect") as BattleSuperArmorEffect2D
		monster.super_armor = true
		other.advance_effect(1.0/30.0)
		check(other.active and other.outline.material != effect.outline.material and other.mirror.get_skeleton_data_res() == other._source.get_skeleton_data_res(), "%s独立材质/骨架与统一霸体入口" % id)
		monster.super_armor = false
		if monster.protection.profile != null and monster.protection.profile.use_as_armor:
			monster.protection.active = true
			other.advance_effect(0.1)
			check(other.active, "%s保护霸体显示描边" % id)
			monster.protection.active = false
		other.clear_effect()
		check(not other.outline.visible and other.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "%s离场禁用快照" % id)
	effect.advance_effect(0.1)
	player.attributes.modify_vital(&"health", -player.attributes.get_vital_value(&"health"))
	check(not effect.active and not effect.outline.visible, "死亡立即清理，不依赖死亡动画完成")
	scene.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS original super armor visual: %d checks; colors/timing, GAS/action/protection, independent GPU silhouettes, skins/facing, pause, Wushuang priority and cleanup" % checks)
		get_tree().quit()
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)
