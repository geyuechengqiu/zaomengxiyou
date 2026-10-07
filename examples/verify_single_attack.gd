extends Node
#region 验收夹具与事件
var demo: Node2D
var session: BattleSession
var player: BattleEntity2D
var target: BattleEntity2D
var hits: Array[Dictionary] = []
var finished: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var starts: Array[Dictionary] = []
var failures: Array[String] = []
var checks: int = 0

func _ready() -> void:
	demo = (load("res://examples/single_attack_demo.tscn") as PackedScene).instantiate()
	add_child(demo)
	session = demo.session
	session.set_physics_process(false)
	CoreSystem.operation_manager.bindings.reset_profile(load("res://data/controls/player_operations.tres"), false)
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	await _fresh()
	await _verify_input_hit_and_idle()
	await _verify_miss_and_kill()
	await _verify_hurtbox_and_mirroring()
	await _verify_window_and_cancellation()
	await _verify_lifecycle()
	CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	session.clear_battle()
	demo.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS stage 6: %d checks; native input to idle, separate hurtbox, hit/miss/kill, persistent-window deduplication, mirrored range, late entry, pause, interrupts, stale IDs and feedback" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _on_event(id: String, payload: Array) -> void:
	if not is_instance_valid(player):
		return
	if payload.size() != 1 or payload[0].get("source_entity_id") != player.entity_id:
		return
	match id:
		"battle.attack.started": starts.append(payload[0].duplicate())
		"battle.attack.impact": impacts.append(payload[0].duplicate())
		"battle.attack.hit": hits.append(payload[0].duplicate())
		"battle.attack.finished": finished.append(payload[0].duplicate())

func _step(count: int, delta: float = 1.0 / 60.0) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		session.advance_physics(delta)

func _fresh() -> void:
	demo.respawn()
	player = demo.player
	target = demo.dummies[1]
	var controller: CoreOperationController = demo.operations.controller
	controller.set_process_input(false)
	controller.set_process_unhandled_input(false)
	for reason in controller.get_control_blocks():
		controller.set_control_blocked(reason, false)
	await _step(8)
	hits.clear()
	impacts.clear()
	starts.clear()
	finished.clear()

func _key(pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_J
	event.physical_keycode = KEY_J
	event.pressed = pressed
	event.echo = echo
	demo.operations.controller.process_native_event(event)
#endregion
#region 输入到扣血反馈与待机
func _verify_input_hit_and_idle() -> void:
	_check(player.combo.definition == null and player.abilities.get_all_ability_ids() == [&"sunwukong_attack1"], "验收实体只配置一个普攻，不预约连击后续段")
	_key(true)
	_key(false)
	await _step(1)
	_check(starts.size() == 1 and player.action_state.current == BattleActionState2D.State.ATTACK, "短按经Core意图和状态机进入一次攻击")
	_check(player.animation.get_current_action() == &"attack_1", "播放预置AnimationPlayer的第一段动作")
	var attack := player.attack_instance
	_check(attack.attacker.get_ref() == player and attack.attacker_id == player.entity_id and attack.faction_id == player.faction_id, "攻击实例保存攻击者、编号与阵营")
	await _step(6)
	_check(hits.is_empty() and target.attributes.get_vital_value(&"health") == 70, "命中窗口之前不扣血")
	await _step(1)
	_check(impacts.size() == 1 and impacts[0].source_frame == 4 and is_equal_approx(impacts[0].skill_time, 4.0 / 30.0), "GAS沿用素材第4帧，不把物理tick当素材帧")
	_check(hits.size() == 1 and target.attributes.get_vital_value(&"health") == 49, "命中木桩，简单伤害26-5扣21")
	_check(target.feedback.hit_count == 1 and target.feedback.last_damage == 21 and target.feedback.get_node("DamageLabel").visible, "伤害数字显示一次，使用实际扣血")
	_check(target.feedback.get_node("HealthBar").value == 49 and target.animation.get_current_action() == &"hurt", "生命条与受击动画即时反馈")
	await _step(3)
	_check(hits.size() == 1 and attack.hit_targets.size() == 1, "持续重叠的后续物理帧不会重复扣血")
	await _step(15)
	_check(player.action_state.current == BattleActionState2D.State.IDLE and player.animation.get_current_action() == &"idle", "攻击结束恢复Core待机和待机动画")
	_check(not attack.active and attack.windows.is_empty() and finished.size() == 1 and finished[0].hit_count == 1, "攻击结束关闭窗口并只通知一次完成")
	_check(player.request_attack(), "同一目标可以被下一次独立攻击命中")
	_check(player.attack_instance.attack_id != attack.attack_id, "再次施放生成新攻击编号")
	await _step(25)
	_check(target.attributes.get_vital_value(&"health") == 28 and hits.size() == 2, "跨施放重置去重，不永久屏蔽目标")
#endregion
#region 打空与击杀
func _verify_miss_and_kill() -> void:
	await _fresh()
	demo.place_far()
	_check(player.request_attack(), "没有目标也可以起手")
	await _step(25)
	_check(hits.is_empty() and target.attributes.get_vital_value(&"health") == 70 and demo.dummies[0].attributes.get_vital_value(&"health") == 70, "打空不会扣任一木桩生命")
	_check(finished.size() == 1 and finished[0].hit_count == 0 and demo.message.text.contains("打空"), "打空也完成反馈和待机闭环")
	await _fresh()
	player.attributes.set_base_value(&"atk", 200)
	player.request_attack()
	await _step(8)
	_check(hits.size() == 1 and hits[0].damage == 70 and hits[0].calculated_damage == 195, "过量伤害反馈区分计算值与实际扣血")
	_check(not target.is_alive() and target.action_state.current == BattleActionState2D.State.DEAD and target.animation.get_current_action() == &"death", "击杀通过Vital和Core死亡状态，播放死亡反馈")
	_check(target.feedback.get_node("HealthLabel").text == "已击杀", "木桩面板显示死亡")
	await _step(20)
	player.request_attack()
	await _step(25)
	_check(hits.size() == 1 and target.feedback.hit_count == 1, "死亡木桩不再接受后续攻击")
#endregion
#region 独立碰撞和受击区域、左右镜像
func _verify_hurtbox_and_mirroring() -> void:
	await _fresh()
	var physical := target.get_node("CollisionShape2D") as CollisionShape2D
	var collision := target.hurtbox.get_node("CollisionShape2D") as CollisionShape2D
	_check(physical.shape != collision.shape and physical.get_parent() == target and collision.get_parent() is BattleHurtbox2D, "物理碰撞体与受击区域是独立可编辑对象")
	_check(player.attack_hitbox != player.hurtbox and player.attack_hitbox.get_child_count() == 1, "攻击区域独立且仍只保留一个攻击框")
	var original_body := target.get_body_rect_global()
	collision.position.x = 500
	player.request_attack()
	await _step(25)
	_check(hits.is_empty() and target.get_body_rect_global() == original_body, "改变受击区域能改变命中结果，不改变物理体")
	await _fresh()
	physical = target.get_node("CollisionShape2D") as CollisionShape2D
	physical.position.x = 500
	player.request_attack()
	await _step(8)
	_check(hits.size() == 1, "物理体移远而受击区域仍在范围内，依然命中")
	await _fresh()
	var right := player.get_attack_rect_local()
	player.animation.set_facing(-1)
	var left := player.get_attack_rect_local()
	_check(is_equal_approx(left.position.x, -right.end.x) and left.size == right.size, "单一攻击框围绕脚底完整镜像")
	player.request_attack()
	await _step(25)
	_check(hits.size() == 1 and hits[0].target_entity_id == demo.dummies[0].entity_id and target.attributes.get_vital_value(&"health") == 70, "向左攻击只击中左木桩，不重复翻转或误伤右木桩")
	await _fresh()
	target.faction_id = player.faction_id
	player.request_attack()
	await _step(25)
	_check(hits.is_empty(), "重叠仍遵守阵营过滤")
	await _fresh()
	target.hurtbox.vulnerable = false
	player.request_attack()
	await _step(25)
	_check(hits.is_empty(), "不可受击区域不接受伤害")
#endregion
#region 持续窗口、暂停、打断与过期事件
func _verify_window_and_cancellation() -> void:
	await _fresh()
	target.position.x = 1000
	player.request_attack()
	await _step(8)
	_check(hits.is_empty(), "窗口刚开启时目标不在范围内")
	target.position.x = 690
	await _step(1)
	_check(hits.size() == 1, "开启后的后续帧进入窗口也能命中")
	await _step(3)
	_check(hits.size() == 1, "后来进入仍只命中一次")
	await _fresh()
	target.position.x = 1000
	player.request_attack()
	await _step(12)
	target.position.x = 690
	await _step(2)
	_check(hits.is_empty(), "窗口关闭以后进入不会造成伤害")
	await _fresh()
	target.position.x = 1000
	player.request_attack()
	await _step(8)
	var elapsed := player.attack_instance.elapsed
	session.set_paused(true)
	target.position.x = 690
	await _step(8)
	_check(hits.is_empty() and player.attack_instance.elapsed == elapsed, "暂停冻结窗口和攻击时间，不扣血")
	session.set_paused(false)
	await _step(1)
	_check(hits.size() == 1, "恢复继续原窗口，不跳过剩余时间")
	await _fresh()
	target.position.x = 1000
	player.request_attack()
	await _step(8)
	var stale := impacts[0].duplicate(true)
	player.receive_damage(1)
	target.position.x = 690
	await _step(3)
	_check(hits.is_empty() and not player.attack_instance.active, "受击打断立即关闭持续窗口")
	await _step(25)
	player.request_attack()
	var next_id := player.attack_instance.attack_id
	player.publish_battle_event(&"battle.attack.impact", stale)
	_check(hits.is_empty() and stale.attack_id != next_id, "同技能重新施放也拒绝上一攻击编号的延迟事件")
	await _step(8)
	_check(hits.size() == 1, "拒绝过期事件不影响新攻击正常命中")
#endregion
#region 生命周期与长按输入
func _verify_lifecycle() -> void:
	await _fresh()
	var interrupt_on_entry := func(id: String, payload: Array) -> void:
		if id == "battle.action_state_changed" and payload.size() == 1 and payload[0].get("source_entity_id") == player.entity_id and player.action_state.current == BattleActionState2D.State.ATTACK:
			player.receive_damage(1.0)
	CoreSystem.event_bus.event_pushed.connect(interrupt_on_entry)
	_check(not player.request_attack() and player.animation.get_current_action() == &"hurt" and starts.is_empty(), "进入攻击状态时同步打断，不覆盖受击动画或发布虚假起手")
	CoreSystem.event_bus.event_pushed.disconnect(interrupt_on_entry)
	await _step(25)
	_check(hits.is_empty() and not player.attack_instance.active, "起手同步打断后不残留命中窗口")
	await _fresh()
	_key(true)
	await _step(1)
	_key(true, true)
	await _step(50)
	_key(false)
	_check(starts.size() == 1 and hits.size() == 1, "长按与系统按键echo不会每帧重启单段攻击")
	await _fresh()
	demo.menu.set_open(true)
	_key(true)
	_key(false)
	await _step(10)
	_check(starts.is_empty(), "菜单打开时攻击键不会发动战斗动作")
	demo.menu.set_open(false)
	await _step(2)
	_check(starts.is_empty(), "关闭菜单不会补发菜单中的攻击")
	await _fresh()
	target.position.x = 1000
	player.request_attack()
	await _step(8)
	var attack := player.attack_instance
	player.receive_damage(10000)
	target.position.x = 690
	await _step(3)
	_check(not attack.active and hits.is_empty() and player.action_state.current == BattleActionState2D.State.DEAD, "攻击者死亡立即撤销窗口且死亡优先")
	await _fresh()
	player.request_attack()
	attack = player.attack_instance
	session.despawn_entity(player.entity_id)
	_check(not attack.active and attack.windows.is_empty(), "实体退出清理攻击实例，攻击者弱引用不保活")
#endregion
