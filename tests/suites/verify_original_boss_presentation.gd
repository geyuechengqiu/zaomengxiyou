extends Node
#region 真实场景、原版UI与出场时钟验收
var scene: Node2D
var session: BattleSession
var feedback: BattleBossFeedback2D
var failures: Array[String] = []
var checks: int = 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func step(delta: float) -> void:
	await get_tree().physics_frame
	session.advance_physics(delta)

func _ready() -> void:
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	add_child(scene)
	session = scene.session
	session.set_physics_process(false)
	scene.flow.stop()
	feedback = session.presentation.get_node("BossFeedback")
	feedback.sound_enabled = false
	await step(0.01)
	await verify_hud()
	await verify_entrance()
	verify_transition()
	scene.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS original Boss presentation: %d checks; original center/name/font/resistance order, HP/protection easing, authored 25-frame entrance, clocks/death/despawn/isolation, expanded transition range and completion guard" % checks)
		get_tree().quit()
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)

func verify_hud() -> void:
	var boss := session.spawn_entity_2d("monsters", &"巨石灵君", Vector2(1100,1056), &"", true)
	boss.ai_controller.enabled = false
	await step(0.01)
	check(not boss.is_spawning() and not boss.feedback.appearance.visible, "Boss原showAppear=0，不伪造出场烟雾")
	check(feedback.name_label.text == "玉石琵琶精" and boss.definition_id == &"巨石灵君", "修正原版显示名同时兼容既有索引")
	check(feedback.bar.global_position.is_equal_approx(Vector2(get_viewport().get_visible_rect().size.x/2,36)), "Boss栏居中挂载于原版y36")
	check(feedback.fill.position == Vector2(-99,27) and feedback.fill.size == Vector2(273,13), "原生命条像素大小和负注册点")
	check(feedback.name_label.get_theme_font(&"font").has_char(0x7435), "原字体包含琵字，名称没有缺字")
	check(feedback.count_label.text == "X3" and not feedback.health_label.visible and not feedback.protect_label.visible, "原三条计数，不显示额外调试数字")
	var first := feedback.resistance_slots.get_child(0) as TextureRect
	var second := feedback.resistance_slots.get_child(1) as TextureRect
	check(first.visible and first.texture.resource_path.ends_with("fireResistRemove.png"), "原火抗降低图标")
	check(second.visible and second.texture.resource_path.ends_with("soilResistAdd.png"), "原土抗提高图标")
	check(is_equal_approx((second.position+second.size/2).x-(first.position+first.size/2).x,30), "原抗性图标中心间隔30")
	check(first.tooltip_text == "火抗 -10" and second.tooltip_text == "土抗 +10", "抗性值为整数")
	check(not feedback.resistance_slots.get_child(2).visible, "零抗性不占位")
	check(feedback.protect.texture_under != null and feedback.protect.texture_under.resource_path.ends_with("protect_background.png") and feedback.protect.value == 0, "零保护值使用原1326深蓝空条，1330仅作填充")
	boss.attributes.set_base_value(&"fireResist", 0)
	await step(0.01)
	check(first.texture.resource_path.ends_with("soilResistAdd.png") and not second.visible, "统一属性入口改变后图标即时整理")
	boss.attributes.set_base_value(&"fireResist", 20)
	await step(0.01)
	check(first.texture.resource_path.ends_with("fireResistAdd.png") and first.tooltip_text == "火抗 +20", "正负改变切换原版图标")
	feedback.difficulty = 1
	await step(0.01)
	check(feedback.name_label.modulate == Color.hex(0xffe00dff), "原困难名称颜色")
	feedback.difficulty = 2
	await step(0.01)
	check(feedback.name_label.modulate == Color.hex(0xf700eeff), "原地狱名称颜色")
	feedback.difficulty = 0
	boss.attributes.get_vital(&"health").set_current_value(1000)
	feedback.advance_feedback(0.3)
	check(absf(feedback.fill.value-lerpf(1.0, (1000.0-778.0)/389.0,0.75)) < 0.001, "原生命0.6秒QuadOut遮罩")
	boss.protection.register_hit({"original_skill_id":1101010,"protection_parameters":{"protectPoint":10000}},1,1167)
	feedback.advance_feedback(0.15)
	check(feedback.protect.visible and feedback.protect.value > 0 and not feedback.protect_label.visible, "原保护条显示，不依赖生命再变化")
	feedback.show_debug_values = true
	feedback.advance_feedback(0)
	check(feedback.health_label.visible and feedback.health_label.text == "1000 / 1167", "可显式开启整数调试值")
	feedback.show_debug_values = false
	session.despawn_entity(boss.entity_id)
	await get_tree().process_frame

func verify_entrance() -> void:
	var actor := session.spawn_entity_2d("monsters", &"剑舞", Vector2(800,1056), &"", true)
	actor.ai_controller.enabled = false
	var view := actor.feedback
	var entrance := view.appearance
	check(actor.is_spawning() and entrance.visible and not actor.animation.visible, "原烟雾先播放，角色延迟显示")
	check(entrance.player.get_animation(&"appear1").track_get_key_count(0) == 25 and is_equal_approx(actor.spawn_remaining,25.0/30), "原25帧30FPS，没有删掉空白尾帧")
	check(entrance.scale == Vector2(2,2) and entrance.get_node("Sprite2D").position == Vector2(-92.05,-140), "原出生脚底注册点与世界2倍比例")
	check(not actor.begin_spawn_appearance(1) and entrance.play_count == 1, "同次出生不会重复启动")
	check(actor.collision_layer == 0 and actor.collision_mask == 0, "原Prefab初始化等待中不参与物理碰撞")
	check(not actor.try_jump() and not actor.try_activate_skill(&"jianwu_skill1"), "出场中不能跳跃或攻击")
	var start := actor.global_position
	await step(0.2)
	check(actor.global_position == start and entrance.player.current_animation_position > 0.19, "出场期间不移动，只推进原帧动画")
	session.set_paused(true)
	var age := entrance.player.current_animation_position
	var remaining := actor.spawn_remaining
	await step(5)
	check(entrance.player.current_animation_position == age and actor.spawn_remaining == remaining, "暂停不跳过出生动画")
	session.set_paused(false)
	session.request_hit_stop(0.1)
	await step(0.1)
	check(actor.spawn_remaining == remaining, "受击停顿同时冻结出场帧")
	session.clock.time_scale = 0.5
	await step(0.2)
	check(absf(actor.spawn_remaining-(remaining-0.1)) < 0.00001, "慢动作只缩放一次出生时间")
	session.clock.time_scale = 1
	await step(1.0)
	check(not actor.is_spawning() and actor.animation.visible and not entrance.visible, "低帧率跨过末帧清理烟雾，剩余时间继续动作系统")
	check(actor.collision_layer != 0 and actor.collision_mask != 0, "出场结束恢复原碰撞配置")
	check(entrance.play_count == 1, "完成后不重播出场")
	var dying := session.spawn_entity_2d("monsters", &"驭兽使", Vector2(900,1056), &"", true)
	var dying_effect := dying.feedback.appearance
	dying.attributes.get_vital(&"health").set_current_value(0)
	check(not dying.is_spawning() and not dying_effect.visible and dying.animation.visible, "出场中死亡立即移除烟雾并交给死亡状态")
	var leaving := session.spawn_entity_2d("monsters", &"复苏容器", Vector2(1200,1056), &"", true)
	var leaving_effect := leaving.feedback.appearance
	check(leaving.is_spawning(), "原容器同样使用showAppear1")
	session.despawn_entity(leaving.entity_id)
	check(not leaving_effect.visible and not leaving_effect.player.is_playing(), "离场停止待播放帧")
	var immediate := session.spawn_entity_2d("monsters", &"剑舞", Vector2(1300,1056))
	immediate.ai_controller.enabled = false
	check(not immediate.is_spawning() and not immediate.feedback.appearance.visible, "工具/验收直接生成可明确省略原出场流程")
	check(actor.spawn_remaining == 0 and immediate.spawn_remaining == 0, "同配置实例出生进度互不污染")
	session.clear_battle()
	check(not entrance.visible and not dying_effect.visible, "关卡退出停止全部出场表现")

func verify_transition() -> void:
	var definition := load("res://data/levels/biyujing/progression/regions/biyujing_region_1.tres") as BattleRegionDefinition
	check(definition.get_automatic_exit_rect() == Rect2(1428,0,940,1216), "清屏切区范围由96扩大到940世界像素")
	check(definition.get_automatic_exit_rect().has_point(Vector2(1800,1056)) and not definition.exit_rect.has_point(Vector2(1800,1056)), "角色离边缘仍有568像素时可进入提前范围")
	var final := load("res://data/levels/biyujing/progression/regions/biyujing_region_5.tres") as BattleRegionDefinition
	check(not final.automatic_exit and final.camera_transition_margin == 0, "最终出口保持原W确认和Boss完成条件")
#endregion
