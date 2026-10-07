extends Node
#region 验收运行状态
const State = BattleActionState2D.State
var demo: Node2D
var session: BattleSession
var player: BattleEntity2D
var failures: Array[String] = []
var checks: int = 0
var started: Array[Dictionary] = []
var impacts: Array[Dictionary] = []
var hits: Array[Dictionary] = []
var landed_states: Array[int] = []
#endregion
#region 测试入口与夹具
func _ready() -> void:
	demo = load("res://examples/wukong_platform_demo.tscn").instantiate()
	demo.enable_player_controls = false
	add_child(demo)
	demo.set_physics_process(false)
	session = demo.session
	session.set_physics_process(false)
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	await _fresh()
	_verify_definitions_and_rules()
	await _verify_attack_ranges()
	await _fresh()
	await _verify_motion()
	await _verify_platforms()
	await _verify_combo()
	await _verify_interruptions()
	await _verify_input_chain()
	CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	session.clear_battle()
	demo.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS stage 4: %d checks; locomotion permissions, real swept collisions, double jump, landing, five GAS combo segments/six hits, priority/armor and input" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)

func _step(count: int = 1, delta: float = 1.0 / 60.0) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		session.advance_physics(delta)
		if is_instance_valid(player):
			landed_states.append(player.action_state.current)

func _fresh(at: Vector2 = Vector2(350, 648)) -> void:
	demo.respawn()
	player = demo.player
	player.position = at
	session.set_time_scale(1.0)
	await _step(8)
	started.clear()
	impacts.clear()
	hits.clear()
	landed_states.clear()

func _on_event(id: String, payload: Array) -> void:
	if payload.size() != 1 or not payload[0] is Dictionary or payload[0].get("battle_id") != session.battle_id:
		return
	if payload[0].get("entity") == player:
		match id:
			"battle.combo.started": started.append(payload[0].duplicate(true))
			"battle.attack.impact": impacts.append(payload[0].duplicate(true))
	if id == "battle.attack.hit" and payload[0].get("source_entity_id") == player.entity_id:
		hits.append(payload[0].duplicate(true))

func _fixture(rect: Rect2, one_way: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = rect.get_center()
	body.collision_layer = 1
	body.collision_mask = 2
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	collision.one_way_collision = one_way
	body.add_child(collision)
	demo.add_child(body)
	return body
#endregion
#region 五段原版 ABRect 与实际伤害边界
func _verify_attack_ranges() -> void:
	var original: Array[Rect2] = [Rect2(-114, -104.95, 267, 99.95), Rect2(-42, -90.95, 210.05, 114.95), Rect2(-171, -103.95, 322, 133.95), Rect2(-94.85, -105.95, 188.65, 159.95), Rect2(-69, -159.95, 324, 184.95)]
	for index in range(5):
		var id := StringName("sunwukong_attack%d" % (index + 1))
		var definition := session.catalog.instantiate_definition("skills", id) as GameplayAbilityDefinition
		var timeline := definition.features[1] as BattleFrameTimelineFeature
		for marker in timeline.events:
			_check(marker.payload.hit_rect.is_equal_approx(original[index]), "每次事件使用对应原版 ABRect，不复用 AI atkRange")
			for facing in [1, -1]:
				await _fresh()
				player.animation.set_facing(facing)
				_check(player.try_activate_skill(id), "边界验证通过真实 GAS 激活对应段")
				var context: Dictionary = marker.payload.duplicate(true)
				var expected := original[index]
				expected.position += Vector2(context.hit_offset)
				if facing < 0:
					expected.position.x = -expected.end.x
				expected = Rect2(expected.position * 2.0, expected.size * 2.0)
				_check(player.get_attack_rect_local(context).is_equal_approx(expected), "缩放、偏移及左右镜像与原版 SkillControl 一致，负显示缩放不翻碰撞框")
				var rect := player.global_transform * expected
				var target: BattleEntity2D = demo.right_target
				demo.left_target.faction_id = player.faction_id
				var radius := target.get_body_rect_global().size.x / 2.0
				var positions: Array[Vector2] = [Vector2(rect.end.x + radius - 1.0, player.position.y), Vector2(rect.end.x + radius + 1.0, player.position.y), Vector2(rect.position.x - radius + 1.0, player.position.y), Vector2(rect.get_center().x, rect.position.y - 1.0)]
				for case_index in range(positions.size()):
					target.position = positions[case_index]
					player.attack_instance.hit_targets.clear()
					player.attack_instance.windows.clear()
					var before := hits.size()
					context["ability_id"] = id
					context["attack_id"] = player.attack_instance.attack_id
					context["source_fps"] = 30.0
					context["source_frame"] = marker.source_frame
					context["skill_time"] = marker.source_frame / 30.0
					player.publish_battle_event(&"battle.attack.impact", context)
					var should_hit := case_index in [0, 2]
					_check(hits.size() == before + (1 if should_hit else 0), "真实 Core→GAS 伤害验证前后边缘内命中、边缘外和框上方不命中")
				_check(not hits.any(func(event): return event.target_entity_id == demo.left_target.entity_id), "覆盖身后仍遵守阵营过滤")
#endregion
#region 定义数据与状态条件表
func _verify_definitions_and_rules() -> void:
	var expected_frames := [10, 10, 12, 18, 20]
	var expected_hits := [[4], [4], [2], [0, 8], [6]]
	var expected_multipliers := [1.0, 1.0, 1.2, 0.45, 2.0]
	_check(player.combo.definition == demo.right_target.combo.definition and player.combo != demo.right_target.combo and player.motion != demo.right_target.motion, "共享只读连击定义，运动与连击运行状态独立")
	for index in range(5):
		var step: BattleAttackStep2D = player.combo.definition.steps[index]
		_check(step.ability_id == StringName("sunwukong_attack%d" % (index + 1)) and player.abilities.has_ability(step.ability_id), "学会语义 ID 的五段技能")
		_check(step.duration_frames == expected_frames[index] and is_equal_approx(player.animation.get_action_duration(step.action), step.get_duration()), "段配置与原生动画时长一致")
		var skill := session.catalog.instantiate_definition("skills", step.ability_id) as GameplayAbilityDefinition
		var timeline := skill.features[1] as BattleFrameTimelineFeature
		_check(timeline.is_configuration_valid() and timeline.events.size() == expected_hits[index].size(), "五段 GAS 素材时间线有效")
		for hit in range(timeline.events.size()):
			_check(timeline.events[hit].source_frame == expected_hits[index][hit] and is_equal_approx(timeline.events[hit].payload.damage_multiplier, expected_multipliers[index]), "保留原版每次命中素材帧和倍率")
	var state := BattleActionState2D.new()
	for current in [State.IDLE, State.MOVE, State.RUN, State.TAKEOFF, State.JUMP, State.LAND, State.ATTACK, State.HURT]:
		state.enter(current)
		_check(state.get_permission(&"move", player.action_profile) == (current not in [State.ATTACK, State.HURT]), "状态表显式决定移动许可")
		_check(state.get_permission(&"turn", player.action_profile) == (current not in [State.ATTACK, State.HURT]), "状态表显式决定转向许可")
		_check(state.can_interrupt(&"death", 0, true, player.action_profile), "死亡优先于全部活着的状态和霸体")
	state.enter(State.ATTACK)
	state.active_rules = {"jump": true, "interrupt_priority": 80, "interrupt_kinds": [&"heavy"]}
	_check(state.can_jump(true, player.action_profile) and not state.can_interrupt(&"normal", 100, false, player.action_profile) and not state.can_interrupt(&"heavy", 70, false, player.action_profile) and state.can_interrupt(&"heavy", 90, true, player.action_profile), "技能覆盖跳跃许可、攻击种类及打断强度")
	state.enter(State.DEAD)
	state.active_rules = {"move": true, "jump": true, "turn": true}
	state.enter(State.IDLE)
	_check(state.current == State.DEAD and not state.get_permission(&"move", player.action_profile) and not state.can_jump(true, player.action_profile), "死亡终态和权限不能被技能覆盖")
	state.dispose()
#endregion
#region 重力、行走、奔跑、朝向与二段跳
func _verify_motion() -> void:
	var landing_serial := player.motion.landing_serial
	await _step(90)
	_check(player.motion.grounded and absf(player.position.y - 650.0) < 0.3 and player.motion.landing_serial == landing_serial, "地面稳定，不重复落地、不悬空")
	player.move_axis = 1.0
	var before := player.position.x
	await _step(20)
	_check(player.action_state.current == State.MOVE and is_equal_approx(player.position.x - before, 210.0 / 3.0), "行走状态与 GAS 速度")
	player.running = true
	before = player.position.x
	await _step(20)
	_check(player.action_state.current == State.RUN and is_equal_approx(player.position.x - before, 100.0), "独立奔跑状态与 GAS 速度")
	player.move_axis = -1.0
	await _step()
	_check(player.animation.get_facing() == -1, "可转向状态更新朝向")
	player.move_axis = 0.0
	await _step()
	_check(player.action_state.current == State.IDLE, "松方向回待机")
	_check(player.try_jump() and player.action_state.current == State.TAKEOFF and not player.try_jump(), "首次起跳明确入态，同 tick 不重复起跳")
	await _step(6)
	_check(player.action_state.current == State.JUMP and player.motion.jumps_used == 1, "起跳后进入空中，保留跳跃预算")
	_check(player.try_jump() and player.motion.jumps_used == 2 and player.animation.get_current_action() == &"jump_2", "空中二段跳使用真实 jumpTwo 动画")
	await _step(6)
	_check(not player.try_jump(), "二段跳后禁止第三跳")
	await _step(80)
	_check(player.motion.grounded and player.motion.jumps_used == 0 and landed_states.has(State.LAND) and player.action_state.current == State.IDLE, "落地先 LAND 再待机，只在支撑接触时恢复预算")
	_check(player.try_jump(), "新一次落地恢复地面起跳许可")
	await _step(65)
#endregion
#region 平台、墙、天花板、边缘与碰撞扫掠
func _verify_platforms() -> void:
	await _fresh(Vector2(2050, 648))
	player.move_axis = 1.0
	player.running = true
	await _step(80)
	_check(player.motion.on_wall and player.position.x <= 2128.2, "持续奔跑不穿墙，记录墙体接触")
	var before := player.position
	await _step(1, 0.7)
	_check(player.position.x <= 2128.2 and player.position.distance_to(before) < 0.3, "大 delta 仍通过扫掠碰撞，不穿墙")
	await _fresh(Vector2(780, 648))
	player.move_axis = 1.0
	player.try_jump()
	await _step(25)
	player.move_axis = 0.0
	await _step(50)
	_check(player.motion.grounded and absf(player.position.y - 520.0) < 0.3, "稳定落在原测试高台")
	await _fresh(Vector2(2550, 648))
	player.move_axis = 1.0
	await _step(45)
	_check(not player.motion.grounded and player.position.y > 650.0 and player.action_state.current == State.JUMP and player.motion.jumps_used == 1, "离开平台边缘下落，不把墙当地面、不悬空")
	player.move_axis = 0.0
	_check(player.try_jump(), "走下边缘只保留一次空中跳跃")
	await _step(6)
	_check(not player.try_jump(), "离开地面不能重获地面跳跃预算")
	var floor := _fixture(Rect2(2700, 650, 600, 120))
	var one_way := _fixture(Rect2(2720, 520, 240, 18), true)
	await _fresh(Vector2(2820, 648))
	_check(player.motion.grounded, "单向平台下方仍站在底层地面")
	player.try_jump()
	await _step(10)
	player.try_jump()
	await _step(16)
	_check(player.position.y < 520.0, "二段跳从下方穿过单向平台")
	await _step(65)
	_check(player.motion.grounded and absf(player.position.y - 520.0) < 0.3, "下落停在单向平台顶面")
	one_way.queue_free()
	var ceiling := _fixture(Rect2(3000, 400, 120, 20))
	await _fresh(Vector2(3060, 648))
	player.try_jump()
	var contacted := false
	for tick in range(18):
		await _step()
		contacted = contacted or player.motion.on_ceiling
		_check(player.position.y >= 600.0 - 0.3, "顶头时不穿过天花板")
	_check(contacted and player.velocity.y >= 0.0, "顶头清除向上速度并开始下落")
	ceiling.queue_free()
	floor.queue_free()
#endregion
#region 五段完整连击、双命中与移动限制
func _verify_combo() -> void:
	await _fresh()
	_check(player.try_attack(), "开始第一段")
	_check(not player.try_attack(), "直接施放不重入正在播放的攻击")
	var durations := [10, 10, 12, 18, 20]
	for index in range(5):
		if index < 4:
			_check(player.request_attack() and player.combo.queued_next and not player.request_attack(), "当前段最多预约一段，不能同 tick 跳过动作")
		var at := player.position
		player.move_axis = -1.0
		await _step(durations[index] * 2)
		if index < 3:
			_check(absf(player.position.x - at.x) < 0.1 and player.animation.get_facing() == 1, "前段锁行走和转向，按相反方向不能偷走")
		if index == 3:
			_check(player.position.x > at.x + 150.0 and player.animation.get_facing() == 1, "第四段仅技能规定的位移生效，玩家转向仍锁定")
		if index < 4:
			_check(player.combo.index == index + 1 and player.animation.get_current_action() == StringName("attack_%d" % (index + 2)), "完成当前段才进入预约段")
	_check(started.map(func(event): return event.combo_step) == [1, 2, 3, 4, 5], "五段严格按 1→2→3→4→5 运行")
	_check(impacts.map(func(event): return event.source_frame) == [4, 4, 2, 0, 8, 6], "第四段两次攻击，总共六个素材事件")
	_check(not player.combo.is_active() and player.action_state.current != State.ATTACK, "第五段结束回运动状态，没有自动循环普攻")
	var right_hits := hits.filter(func(event): return event.target_entity_id == demo.right_target.entity_id)
	_check(right_hits.any(func(event): return event.combo_step == 3 and is_equal_approx(event.damage, 25.2)), "第三段 GAS 伤害倍率 1.2 生效")
	_check(not demo.right_target.combo.is_active(), "另一实体的共享定义不带走自己的连击状态")
	await _fresh(Vector2(2100, 648))
	player.try_activate_skill(&"sunwukong_attack4")
	await _step(36)
	_check(player.position.x <= 2128.2, "第四段技能位移仍被墙体限制")
	await _fresh()
	player.animation.set_facing(-1)
	demo.left_target.position.x = 200.0
	demo.right_target.position.x = 480.0
	player.try_activate_skill(&"sunwukong_attack4")
	await _step(17)
	var second: Dictionary = impacts.back()
	_check(hits.any(func(event): return event.hit_index == 1 and event.target_entity_id == demo.left_target.entity_id) and hits.any(func(event): return event.hit_index == 2 and event.target_entity_id == demo.right_target.entity_id), "第四段两击按原版覆盖身前身后并跟随角色位移")
	_check(second.source_frame == 8 and second.hit_scale_x == -1 and second.hit_offset == Vector2(-17, -4), "第四段保留第二击的显示缩放和原版偏移")
	var left_rect := player.get_attack_rect_local(second)
	player.animation.set_facing(1)
	var right_rect := player.get_attack_rect_local(second)
	_check(is_equal_approx(left_rect.position.x, -right_rect.end.x), "带偏移的反向攻击也能整体左右镜像")
	player.animation.set_facing(-1)
	var hit_count := hits.size()
	player.publish_battle_event(&"battle.attack.impact", second)
	_check(hits.size() == hit_count, "重复同次事件不重复伤害同个目标")
#endregion
#region 打断、霸体、跳取消、暂停与死亡优先级
func _verify_interruptions() -> void:
	await _fresh()
	player.try_attack()
	player.request_attack()
	await _step(2)
	player.receive_damage(1)
	_check(player.action_state.current == State.HURT and not player.combo.is_active() and not player.abilities.get_ability_instance(&"sunwukong_attack1").is_active, "普通受击打断攻击并取消预约/GAS")
	await _step(25)
	_check(started.size() == 1 and impacts.is_empty(), "被打断后不补发未来命中或预约段")
	player.try_attack()
	player.super_armor = true
	var hp := player.attributes.get_vital_value(&"health")
	player.receive_damage(1)
	_check(player.action_state.current == State.ATTACK and player.combo.is_active() and player.attributes.get_vital_value(&"health") == hp - 1.0, "霸体阻止普通硬直，仍实际扣血")
	player.receive_damage(1, null, &"heavy", 90)
	_check(player.action_state.current == State.HURT and not player.combo.is_active(), "足够优先级的重攻击打断霸体技能")
	await _step(25)
	player.super_armor = false
	player.try_attack()
	player.action_state.active_rules["interrupt_priority"] = 80
	player.receive_damage(1, null, &"heavy", 70)
	_check(player.action_state.current == State.ATTACK, "低强度攻击不能覆盖技能优先级")
	player.receive_damage(1, null, &"heavy", 90)
	_check(player.action_state.current == State.HURT, "高强度攻击覆盖技能优先级")
	await _step(25)
	player.try_attack()
	player.request_attack()
	_check(player.try_jump() and not player.combo.is_active() and not player.abilities.get_ability_instance(&"sunwukong_attack1").is_active, "原版 jumpNormal 规则允许地面跳取消普通攻击，清预约")
	await _step(70)
	player.try_attack()
	await _step(2)
	var track := (player.animation as SpineAnimationAdapter).get_track_time()
	var at := player.position
	session.set_paused(true)
	await _step(15)
	_check(player.position == at and (player.animation as SpineAnimationAdapter).get_track_time() == track, "暂停不推进运动或连击动画")
	session.set_paused(false)
	session.set_time_scale(0.5)
	await _step(2)
	_check(is_equal_approx((player.animation as SpineAnimationAdapter).get_track_time() - track, 1.0 / 60.0), "连击与动作状态同受战斗慢动作缩放")
	session.set_time_scale(1.0)
	player.super_armor = true
	player.action_state.active_rules["interrupt_priority"] = 99999
	player.receive_damage(10000, null, &"normal", 0)
	_check(player.action_state.current == State.DEAD and not player.combo.is_active() and player.velocity.x == 0.0 and not player.try_jump() and not player.request_attack(), "致死伤害越过霸体/技能优先级，死亡最高且终态")
	player.animation.action_completed.emit(&"death")
	await _step(40)
	_check(player.action_state.current == State.DEAD, "完成动画不能解除死亡状态")
#endregion
#region 实际操作意图进入五段链
func _verify_input_chain() -> void:
	await _fresh()
	var operations := BattlePlayerOperations.new()
	operations.operation_profile = load("res://data/controls/player_operations.tres")
	player.operations = operations
	player.add_child(operations)
	operations.controller.native_input_enabled = false
	for index in range(5):
		operations.controller.pulse_intent(&"attack", &"verification")
		await _step()
		if index > 0:
			var wait_frames := player.combo.get_step().duration_frames
			for tick in range(wait_frames * 2 + 1):
				if player.combo.index == index:
					break
				await _step()
		_check(player.combo.index == index, "短按意图进入对应连击段")
	await _step(45)
	_check(started.map(func(event): return event.combo_step) == [1, 2, 3, 4, 5] and not player.combo.is_active(), "五次意图形成完整五段，不需要角色读取按键")
	operations.controller.submit_intent(&"attack", 1.0)
	await _step(60)
	_check(started.size() == 6 and not player.combo.is_active(), "长按只发起一段，不自动连击")
	operations.controller.submit_intent(&"attack", 0.0)
	operations.controller.pulse_intent(&"attack")
	await _step()
	operations.controller.pulse_intent(&"attack")
	await _step()
	_check(player.combo.queued_next, "操作已预约后续段")
	operations.set_control_blocked(&"menu", true)
	_check(not player.combo.queued_next, "菜单撤回控制同步清掉已经受理的连击预约")
	await _step(30)
	_check(not player.combo.is_active(), "失去控制后完成当前段但不自动进入下一段")
#endregion
