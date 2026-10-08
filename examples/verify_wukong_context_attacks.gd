extends Node
#region 原生输入、事件与真实场景夹具
const State = BattleActionState2D.State
var demo: Node2D
var player: BattleEntity2D
var session: BattleSession
var controller: CoreOperationController
var checks: int = 0
var failures: Array[String] = []
var hits: Array[Dictionary] = []
var starts: Array[Dictionary] = []
var turns: Array[Dictionary] = []

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _ready() -> void:
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	await _verify_definitions_and_preview()
	await _verify_run_attack()
	await _verify_jump_attack()
	await _verify_turn_window()
	CoreSystem.operation_manager.bindings.reset_profile(load("res://data/controls/player_operations.tres"), false)
	CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	demo.free()
	if failures.is_empty():
		print("PASS wukong context attacks: %d checks; native keys/run/jump/Core states/original hitboxes/windows/effects/damage/pause/cancel/one-shot reverse/motion lock/fifth direction/remapping" % checks)
		get_tree().quit()
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _fresh() -> void:
	if is_instance_valid(demo):
		demo.free()
	demo = load("res://examples/original_damage_demo.tscn").instantiate()
	add_child(demo)
	demo.set_process(false)
	session = demo.session
	session.set_physics_process(false)
	player = demo.player
	controller = player.operations.controller
	controller.set_process_input(false)
	controller.set_process_unhandled_input(false)
	CoreSystem.operation_manager.bindings.reset_profile(load("res://data/controls/player_operations.tres"), false)
	await _steps(8)
	hits.clear()
	starts.clear()
	turns.clear()

func _steps(count: int, delta: float = 1.0 / 60.0) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		session.advance_physics(delta)

func _key(code: int, down: bool = true) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	controller.process_native_event(event)

func _consume() -> void:
	player.operations.advance_simulation(1.0 / 60.0)

func _on_event(id: String, payload: Array) -> void:
	if payload.size() != 1 or not is_instance_valid(player) or payload[0].get("battle_id") != session.battle_id or payload[0].get("source_entity_id") != player.entity_id:
		return
	match id:
		"battle.attack.hit": hits.append(payload[0].duplicate(true))
		"battle.attack.started": starts.append(payload[0].duplicate(true))
		"battle.combo.turned": turns.append(payload[0].duplicate(true))
#endregion
#region 两个原动作、特效、时长与可编辑单一判定框
func _verify_definitions_and_preview() -> void:
	await _fresh()
	for data in [[&"run_attack", &"sunwukong_run_attack", 12, 3, Rect2(-98, -84.95, 290, 90.95)], [&"jump_attack", &"sunwukong_jump_attack", 13, 5, Rect2(-100, -137.95, 251, 158.95)]]:
		var definition := session.catalog.instantiate_definition("skills", data[1]) as GameplayAbilityDefinition
		var timeline := definition.features[0] as BattleFrameTimelineFeature
		_check(player.abilities.has_ability(data[1]) and timeline.is_configuration_valid(), "上下文技能已学习，GAS时间轴配置有效")
		_check(player.action_state.machine.states.has(&"RUN_ATTACK") and player.action_state.machine.states.has(&"JUMP_ATTACK"), "Core拥有独立跑攻和跳攻叶子")
		_check(timeline.duration_frames == data[2] and is_equal_approx(player.animation.get_action_duration(data[0]), data[2] / 30.0), "战斗时间与原动画时长一致")
		_check(timeline.attack_segments[0].hit_rect == data[4] and timeline.attack_segments[0].start_frame == data[3], "读取原SWF的ABRect与原技能触发帧")
		var visual := player.animation as SpineAnimationAdapter
		var primary := visual.get_node("AttackEffects/Primary") as SpineSprite
		for time in [0.0, data[3] / 30.0 + 0.01, 0.41]:
			visual.play_action(data[0], true)
			visual.advance_animation(time)
			_check(primary.visible == (time >= data[3] / 30.0 and time < 0.4), "新攻击特效只在原素材窗口显示")
			_check(not (visual.get_node("AttackEffects/Secondary") as SpineSprite).visible, "新攻击不继承第四段第二特效")
			player.attack_hitbox.preview_action = data[0]
			player.attack_hitbox.preview_time = time
			player.attack_hitbox._refresh_preview()
			_check(player.attack_hitbox.action == data[0], "单一攻击框能够读取新技能进行预览")
		visual.play_action(&"idle", true)
#endregion
#region 跑步按攻击、冲刺碰撞、重复命中与中断
func _verify_run_attack() -> void:
	for facing in [1, -1]:
		await _fresh()
		_key(KEY_D if facing > 0 else KEY_A)
		_key(KEY_SHIFT)
		await _steps(1)
		_check(player.action_state.current == State.RUN, "方向与奔跑意图进入RUN")
		var origin := player.position
		_key(KEY_J)
		_consume()
		_check(player.action_state.current == State.RUN_ATTACK and player.animation.get_current_action() == &"run_attack" and not player.combo.is_active(), "RUN攻击键进入独立跑攻，不误起五连击")
		_check(player.attack_instance.facing == facing and not player.try_jump(), "跑攻起手朝向正确并锁定跳跃")
		await _steps(6)
		_check(hits.size() == 1 and hits[0].ability_id == &"sunwukong_run_attack" and is_equal_approx(hits[0].sample_time, 0.1) and hits[0].calculated_damage == 96, "原第3帧命中，原1.2倍率扣血")
		await _steps(18)
		_check(is_equal_approx(player.position.x - origin.x, 192.0 * facing), "原240源单位每秒，按2倍坐标冲刺12帧")
		_check(hits.size() == 1 and not player.attack_instance.active and player.action_state.current == State.RUN, "持续重叠只命中一次，技能结束恢复RUN")
		await _steps(6)
		_check(starts.size() == 1, "长按攻击不会重复跑攻")
	await _fresh()
	_key(KEY_D)
	_key(KEY_SHIFT)
	await _steps(1)
	_key(KEY_J)
	_consume()
	await _steps(4)
	var frozen := player.position
	var elapsed := player.attack_instance.elapsed
	session.set_paused(true)
	await _steps(6)
	_check(player.position == frozen and player.attack_instance.elapsed == elapsed, "暂停冻结跑攻位移与动画时间轴")
	session.set_paused(false)
	player.receive_damage(1)
	var cast := player.attack_instance
	await _steps(12)
	_check(not cast.active and hits.is_empty() and player.animation.get_current_action() == &"hurt", "前摇受击取消跑攻，旧命中和特效清理")
	await _fresh()
	var wall := StaticBody2D.new()
	wall.position = player.position + Vector2(130, -250)
	wall.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 500)
	shape.shape = rectangle
	wall.add_child(shape)
	demo.add_child(wall)
	_key(KEY_D)
	_key(KEY_SHIFT)
	await _steps(1)
	var origin := player.position
	_key(KEY_J)
	_consume()
	await _steps(1, 0.4)
	_check(player.position.x <= origin.x + 98.1 and player.motion.grounded, "低帧率跑攻扫掠不穿墙、不悬空")
	await _fresh()
	var platform := StaticBody2D.new()
	platform.position = player.position + Vector2(0, -290)
	platform.collision_layer = 1
	shape = CollisionShape2D.new()
	rectangle = RectangleShape2D.new()
	rectangle.size = Vector2(60, 20)
	shape.shape = rectangle
	platform.add_child(shape)
	demo.add_child(platform)
	player.position.y -= 300.0
	player.velocity = Vector2.ZERO
	player.motion.grounded = false
	await _steps(4)
	_check(player.motion.grounded, "窄高台实际接触后允许跑攻")
	_key(KEY_D)
	_key(KEY_SHIFT)
	await _steps(1)
	_key(KEY_J)
	_consume()
	cast = player.attack_instance
	await _steps(1, 0.4)
	_check(not cast.active and not player.motion.grounded and player.action_state.current == State.JUMP, "低帧率冲出平台时取消跑攻并进入空中")
	await _steps(4)
	_check(hits.is_empty() and player.velocity.y > 0.0, "离地后旧时间轴不再命中，重力继续下落")
#endregion
#region 跳跃按攻击、自然下落、落地和死亡清理
func _verify_jump_attack() -> void:
	await _fresh()
	_key(KEY_K)
	_key(KEY_J)
	_consume()
	_check(player.action_state.current == State.JUMP_ATTACK and player.animation.get_current_action() == &"jump_attack" and not player.motion.grounded, "同tick先跳后攻进入独立JUMP_ATTACK")
	_check(not player.try_activate_skill(&"sunwukong_attack1") and not player.try_jump(), "跳攻期间不发动地面连击或重复起跳")
	player.animation.action_completed.emit(&"jump_attack")
	_check(player.action_state.current == State.JUMP_ATTACK, "动画完成事件不能跳过战斗锁定")
	await _steps(9)
	_check(hits.is_empty(), "跳攻原第5帧之前无伤害")
	await _steps(1)
	_check(hits.size() == 1 and hits[0].ability_id == &"sunwukong_jump_attack" and hits[0].calculated_damage == 104, "第5帧使用原1.3倍率命中木桩")
	var x := player.position.x
	_key(KEY_D)
	await _steps(12)
	_check(player.position.x > x and player.action_state.current == State.JUMP_ATTACK, "原canWalk许可保留空中横向操控")
	await _steps(4)
	_check(player.action_state.current == State.JUMP and not player.attack_instance.active and hits.size() == 1, "第13帧结束回空中状态，持续重叠只命中一次")
	await _steps(40)
	_check(player.motion.grounded and player.motion.jumps_used == 0, "跳攻持续重力，正常落地并恢复跳跃预算")
	await _fresh()
	_key(KEY_K)
	_consume()
	await _steps(2)
	_key(KEY_J)
	_consume()
	var cast := player.attack_instance
	# 靠近地面且正在下降，下一步必须先落地取消旧空中攻击。
	player.position.y = demo.dummies[1].position.y - 1.0
	player.velocity.y = 150.0
	await _steps(1)
	_check(player.motion.grounded and not cast.active and player.action_state.current == State.LAND and hits.is_empty(), "落地立即取消跳攻，未执行攻击段清理")
	await _fresh()
	_key(KEY_K)
	_key(KEY_J)
	_consume()
	cast = player.attack_instance
	player.receive_damage(100000)
	await _steps(12)
	_check(player.action_state.current == State.DEAD and not cast.active and hits.is_empty(), "死亡优先于跳攻并取消旧时间轴")
#endregion
#region 第四段半开窗口只接受反向pressed一次，位移与第五段方向分离
func _verify_turn_window() -> void:
	for facing in [1, -1]:
		await _fresh()
		player.animation.set_facing(facing)
		_check(player.try_activate_skill(&"sunwukong_attack4"), "真实GAS发动第四段")
		await _steps(14)
		_key(KEY_A if facing > 0 else KEY_D)
		_consume()
		_check(player.animation.get_facing() == facing and not player.combo.turn_used, "第7帧窗口前新按反向不转身")
		await _steps(2)
		_check(player.animation.get_facing() == facing and not player.combo.turn_used, "提前按住反向跨窗口，不把held当作新pressed")
		_key(KEY_A if facing > 0 else KEY_D, false)
		_key(KEY_A if facing > 0 else KEY_D)
		var cast := player.attack_instance
		var time := player.animation.get_playback_time()
		var velocity := player.velocity
		var hit_records := cast.hit_targets.duplicate(true)
		_consume()
		_check(player.combo.turn_used and player.animation.get_facing() == -facing and turns.size() == 1, "第8帧包含在窗口内，新按反向只转一次")
		_check(player.velocity == velocity and cast.motion_facing == facing and player.combo.motion_facing == facing and cast.facing == -facing, "立即保留速度及位移方向，只更新视觉与攻击朝向")
		_check(player.attack_instance == cast and cast.hit_targets == hit_records and player.animation.get_playback_time() == time, "转身不重建施放、命中记录或动画进度")
		_check(signf((player.animation.get_node("AttackEffects") as Node2D).scale.x) == -facing, "当前第四段特效也随角色翻转")
		var origin := player.position.x
		await _steps(2)
		_check(signf(player.velocity.x) == facing and signf(player.position.x - origin) == facing, "后续tick仍沿起手速度方向移动")
		_key(KEY_D if facing > 0 else KEY_A)
		_consume()
		_check(player.animation.get_facing() == -facing and turns.size() == 1, "同窗口第二次反向按下不能再转回")
		_key(KEY_J)
		_consume()
		await _steps(18)
		_check(player.combo.index == 4 and player.animation.get_current_action() == &"attack_5" and player.attack_instance.facing == -facing, "已预约第五段沿第四段转身后的朝向释放")
		_check(not player.combo.turn_used and player.combo.motion_facing == -facing, "新段重置转身额度并重新快照位移朝向")
	await _fresh()
	player.try_activate_skill(&"sunwukong_attack4")
	await _steps(32)
	_key(KEY_A)
	_consume()
	_check(not player.combo.turn_used and player.animation.get_facing() == 1, "第16帧是半开窗口终点，不再允许转身")
	await _fresh()
	player.try_activate_skill(&"sunwukong_attack4")
	await _steps(16)
	demo.menu.set_open(true)
	_key(KEY_A)
	_consume()
	_check(not player.combo.turn_used and player.animation.get_facing() == 1, "菜单控制权阻断方向转身")
	demo.menu.set_open(false)
	_key(KEY_A, false)
	_key(KEY_A)
	_consume()
	_check(player.combo.turn_used, "关闭菜单后新按下恢复控制")
	await _fresh()
	player.try_activate_skill(&"sunwukong_attack4")
	await _steps(16)
	# 真正按键重映射，不修改角色逻辑。
	var binding := InputEventKey.new()
	binding.physical_keycode = KEY_C
	binding.keycode = KEY_C
	_check(CoreSystem.operation_manager.bindings.set_binding(&"battle_player.left", binding, false), "方向键可重映射")
	_key(KEY_A)
	_consume()
	_check(not player.combo.turn_used, "重映射后旧键不触发转身")
	_key(KEY_C)
	_consume()
	_check(player.combo.turn_used and player.animation.get_facing() == -1, "新键经过相同方向意图转身")
	player.cancel_skill()
	_check(not player.combo.turn_used and not player.attack_instance.active, "取消释放清除窗口使用状态与攻击区域")
	var step := BattleAttackStep2D.new()
	step.turn_window_start_frame = 8
	step.turn_window_end_frame = 8
	_check(not step.is_turn_window_valid(), "无宽度转身窗不能通过配置校验")
#endregion
