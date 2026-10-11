extends Node
#region 原版支援Buff与BossComing实际主关卡验收
var scene: Node2D
var session: BattleSession
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
	await verify_healing()
	await verify_boss_entrance()
	scene.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS Pipa support/Boss entrance: %d checks; original allied healing/interval/formula/expiration, no offensive hit, pooled original visual, pause, death/despawn, 33-frame screen entrance" % checks)
		get_tree().quit()
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)

func verify_healing() -> void:
	var player := scene.player as BattleEntity2D
	player.global_position = Vector2(500,1056)
	var initial_hp := player.attributes.get_vital_value(&"health")
	var ally := session.spawn_entity_2d("monsters", &"剑舞", Vector2(7200,1056))
	ally.ai_controller.enabled = false
	ally.attributes.set_base_value(&"hpMax",1000)
	ally.attributes.set_base_value(&"atk",20)
	ally.attributes.set_base_value(&"reHP",0)
	ally.attributes.get_vital(&"health").set_current_value(100)
	var vessel := session.spawn_entity_2d("monsters", &"复苏容器",Vector2(8000,1056))
	vessel.attributes.set_base_value(&"hpMax",400)
	vessel.attributes.set_base_value(&"atk",10)
	vessel.attributes.set_base_value(&"reHP",0)
	vessel.attributes.get_vital(&"health").set_current_value(100)
	for index in range(60):
		await step(1.0/60)
		if ally.statuses.has_status(&"pipa_healing"): break
	check(vessel.ai_controller.successful_casts == 1, "远离玩家仍主动施放支援技能")
	check(ally.statuses.has_status(&"pipa_healing") and vessel.statuses.has_status(&"pipa_healing"), "同阵营单位及施放者均获得Buff，不限制敌对攻击框")
	check(not player.statuses.has_status(&"pipa_healing") and player.attributes.get_vital_value(&"health") == initial_hp, "玩家不获敌方Buff也不受琵琶攻击")
	vessel.ai_controller.enabled = false
	check(ally.attributes.get_vital_value(&"health") == 100, "isImmediate=0，施放不立即回血")
	var instance := ally.statuses.get_status(&"pipa_healing")
	if instance == null:
		return
	var feature := instance.status_data.features[0] as FeaturePeriodicEffects
	var elapsed := feature._get_timer(instance)
	var numbers_before := session.presentation.number_rows.created_count + session.presentation.number_rows.reused_count
	await step(2.0-elapsed-0.001)
	check(ally.attributes.get_vital_value(&"health") == 100, "不足两秒不结算")
	await step(0.001)
	check(ally.attributes.get_vital_value(&"health") == 200, "目标生命1000攻击20：int(50+40+10)=100")
	check(vessel.attributes.get_vital_value(&"health") == 150, "另一实例生命400攻击10：int(20+20+10)=50")
	check(session.presentation.number_rows.created_count + session.presentation.number_rows.reused_count >= numbers_before+2, "两次回血进入共享跳字池")
	check(ally.feedback.healing_buff.visible and vessel.feedback.healing_buff.visible, "原5004十四帧循环Buff特效")
	session.set_paused(true)
	var age := ally.feedback.healing_buff.age
	await step(3)
	check(ally.feedback.healing_buff.age == age and ally.attributes.get_vital_value(&"health") == 200, "暂停冻结Buff与视觉时间")
	session.set_paused(false)
	await step(8)
	check(ally.attributes.get_vital_value(&"health") == 600 and not ally.statuses.has_status(&"pipa_healing"), "跨帧补齐剩余四次，两秒一次十秒到期")
	check(not ally.feedback.healing_buff.visible, "到期清除原回血光效")
	ally.apply_status_definition(&"pipa_healing",vessel)
	await step(0.1)
	check(ally.feedback.healing_buff.visible, "重新施加可以重新显示")
	vessel.attributes.get_vital(&"health").set_current_value(0)
	await step(0.1)
	check(ally.statuses.has_status(&"pipa_healing"), "destroyBySend=0：施放者死亡不提前移除友军Buff")
	ally.attributes.get_vital(&"health").set_current_value(0)
	await step(0.1)
	check(not ally.feedback.healing_buff.visible, "目标死亡立即清理回血表现")
	session.despawn_entity(ally.entity_id)
	session.despawn_entity(vessel.entity_id)
	await get_tree().process_frame
	var reused := session.spawn_entity_2d("monsters", &"驭兽使",Vector2(7600,1056))
	reused.ai_controller.enabled = false
	check(not reused.feedback.healing_buff.visible and not reused.statuses.has_status(&"pipa_healing"), "复用反馈节点不继承旧Buff")
	session.despawn_entity(reused.entity_id)
	await get_tree().process_frame

func verify_boss_entrance() -> void:
	var boss := session.spawn_entity_2d("monsters", &"巨石灵君",Vector2(8000,1056), &"",true)
	boss.ai_controller.enabled = false
	var feedback := session.presentation.get_node("BossFeedback") as BattleBossFeedback2D
	var clip := feedback.entrance
	check(clip.visible and clip.play_count == 1, "Boss注册只启动一次原屏幕出场动画")
	check(not boss.is_spawning() and not boss.feedback.appearance.visible, "showAppear=0，不错误添加普通烟雾或隐藏Boss身体")
	check(clip.player.get_animation(&"play").track_get_key_count(0) == 33 and is_equal_approx(clip.player.get_animation(&"play").length,1.1), "bossComing原33帧30FPS")
	check(clip.position == Vector2.ZERO and clip.scale == Vector2.ONE, "原940×590屏幕注册位置，不随世界坐标镜像缩放")
	feedback.bind_boss(boss)
	check(clip.play_count == 1, "重复绑定Boss不重复登场")
	await step(0.4)
	check(clip.visible and clip.get_node("Sprite2D").texture != null, "中间帧播放真实原素材")
	session.set_paused(true)
	var age := clip.age
	await step(2)
	check(clip.age == age, "暂停不跳过BossComing")
	session.set_paused(false)
	await step(0.8)
	check(not clip.visible and not clip.player.is_playing(), "跨过末帧立即隐藏无残留")
	session.despawn_entity(boss.entity_id)
	await get_tree().process_frame
	boss = session.spawn_entity_2d("monsters", &"巨石灵君",Vector2(8000,1056), &"",true)
	boss.ai_controller.enabled = false
	check(clip.visible and clip.play_count == 2, "新Boss实例可以重新触发")
	session.despawn_entity(boss.entity_id)
	check(not clip.visible, "Boss离场清理未完成登场动画")
	await get_tree().process_frame
#endregion
