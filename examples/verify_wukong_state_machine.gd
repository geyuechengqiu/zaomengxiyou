extends Node
#region 验收状态
const State = BattleActionState2D.State
var demo: Node2D
var player: BattleEntity2D
var session: BattleSession
var checks: int = 0
var failures: Array[String] = []
var lifecycle: Array[String] = []
var state_events: Array[Dictionary] = []
var baseline_count: int = 0
var machine_start_signals: int = 0
#endregion
#region 验收入口与固定战斗更新
func _ready() -> void:
	baseline_count = CoreSystem.state_machine_manager.get_all_state_machine_ids().size()
	demo = load("res://examples/wukong_platform_demo.tscn").instantiate()
	demo.enable_player_controls = false
	add_child(demo)
	demo.set_physics_process(false)
	session = demo.session
	session.damage_strategy = SimpleDamageLogic.new()
	session.set_physics_process(false)
	player = demo.player
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	await _steps(8)
	_verify_registration()
	await _verify_lifecycle_and_clock()
	await _verify_combo_and_death()
	await _verify_cleanup()
	CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	demo.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS Wukong Core state machine: %d checks; real Core leaves/lifecycle/registry, unique combat clock, combo reentry, death guards and disposal" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)

func _steps(count: int, delta: float = 1.0 / 60.0) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		session.advance_physics(delta)

func _on_event(id: String, payload: Array) -> void:
	if id == "battle.action_state_changed" and payload.size() == 1 and payload[0].get("entity") == player:
		state_events.append(payload[0].duplicate(true))

func _on_idle_exit() -> void:
	lifecycle.append("idle_exit")

func _on_move_enter(_message: Dictionary) -> void:
	lifecycle.append("move_enter")

func _on_machine_started(id: StringName) -> void:
	if id == player.action_state.registration_id:
		machine_start_signals += 1
#endregion
#region 确认真正使用 Core 状态机与九个独立叶子
func _verify_registration() -> void:
	var manager := CoreSystem.state_machine_manager
	var actions := player.action_state
	_check(actions.machine is BaseStateMachine and actions.machine.states.size() == BattleActionLeafState2D.Kind.size(), "基础动作与阶段9受击叶子均由 Core BaseStateMachine 持有")
	_check(manager.get_state_machine(actions.registration_id) == actions.machine and manager.get_current_state(actions.registration_id) == actions.machine.current_state, "Core 管理器查询真实动作机与当前叶子")
	_check(manager.get_all_state_machine_ids().size() == baseline_count + 3, "三个实体各自注册一台机器")
	_check(actions.registration_id != demo.left_target.action_state.registration_id and actions.machine != demo.right_target.action_state.machine, "多实体状态机及注册 ID 隔离")
	for name in BattleActionLeafState2D.NAMES:
		var leaf: BaseState = actions.machine.states[name]
		_check(leaf is BattleActionLeafState2D and leaf.state_machine == actions.machine and leaf.agent == player and leaf != demo.right_target.action_state.machine.states[name], "Core 叶子所属关系、agent 与实例独立")
	_check(actions.current == State.IDLE and actions.get_name() == "IDLE" and actions.machine.current_state.is_active, "旧语义入口读取当前 Core 叶子")
#endregion
#region 进入、退出、消息规则、直接 Core 跳转和唯一时钟
func _verify_lifecycle_and_clock() -> void:
	var actions := player.action_state
	var idle: BattleActionLeafState2D = actions.machine.states[&"IDLE"]
	var move: BattleActionLeafState2D = actions.machine.states[&"MOVE"]
	idle.state_exited.connect(_on_idle_exit)
	move.state_entered.connect(_on_move_enter)
	actions.enter(State.MOVE, {"turn": false})
	_check(lifecycle == ["idle_exit", "move_enter"] and not idle.is_active and move.is_active, "Core exit/enter 生命周期严格顺序且只有一个叶子活跃")
	_check(actions.machine.previous_state == &"IDLE" and actions.current == State.MOVE and actions.elapsed == 0.0, "Core 保存历史，进入状态重置本叶子时间")
	_check(not actions.get_permission(&"turn", player.action_profile) and state_events.back().action_rules.turn == false, "切换消息先安装技能规则，再通知状态改变")
	_check(CoreSystem.state_machine_manager.transition_state_machine(actions.registration_id, &"RUN") and actions.current == State.RUN and actions.machine.previous_state == &"MOVE" and move.active_rules.is_empty(), "Core 管理器切换同步旧接口并调用退出清理")
	_check(demo.right_target.action_state.current == State.IDLE, "Core 跳转不污染另一实体")
	idle.state_exited.disconnect(_on_idle_exit)
	move.state_entered.disconnect(_on_move_enter)
	actions.enter(State.IDLE)
	var before := actions.elapsed
	for tick in range(8):
		await get_tree().physics_frame
	_check(actions.elapsed == before, "真实引擎 tick 不经 Core 管理器重复推进战斗状态")
	await _steps(1)
	_check(is_equal_approx(actions.elapsed - before, 1.0 / 60.0), "状态仅接收一次 combat delta")
	session.set_paused(true)
	before = actions.elapsed
	await _steps(8)
	_check(actions.elapsed == before, "暂停保持 Core 叶子计时")
	session.set_paused(false)
	session.set_time_scale(0.5)
	await _steps(2)
	_check(is_equal_approx(actions.elapsed - before, 1.0 / 60.0), "Core 叶子使用缩放后的战斗时间")
	session.set_time_scale(1.0)
#endregion
#region 攻击重入、GAS 时长与死亡无法经 Core 绕过
func _verify_combo_and_death() -> void:
	var actions := player.action_state
	_check(player.try_attack() and actions.machine.current_state.state_id == &"ATTACK", "发动技能真正进入 Core ATTACK")
	var attack: BattleActionLeafState2D = actions.machine.current_state
	_check(actions.active_rules.jump and not actions.get_permission(&"move", player.action_profile), "原普攻跳取消与移动限制保留")
	player.request_attack()
	await _steps(20)
	_check(player.combo.index == 1 and actions.machine.current_state == attack and actions.elapsed == 0.0, "连击推进通过同一 Core ATTACK 的退出/重入，段时间重置")
	_check(state_events.any(func(event): return event.from_state == &"ATTACK" and event.to_state == &"ATTACK"), "Core 同态重入发出状态改变通知")
	await _steps(20)
	_check(actions.current == State.IDLE and not attack.is_active, "当前 GAS 段结束后由 Core 叶子退出攻击")
	player.try_attack()
	player.super_armor = true
	player.receive_damage(1)
	_check(actions.current == State.ATTACK, "霸体拒绝普通打断")
	player.receive_damage(1, null, &"heavy", 90)
	_check(actions.machine.current_state.state_id == &"HURT" and not player.combo.is_active(), "重攻击进入 Core HURT 并取消连击")
	player.receive_damage(10000)
	_check(actions.machine.is_terminal_dead() and actions.current == State.DEAD, "Vital 耗尽进入最高优先级死亡终态")
	_check(not CoreSystem.state_machine_manager.transition_state_machine(actions.registration_id, &"IDLE") and actions.current == State.DEAD, "Core 管理器不能绕过死亡，拒绝时返回 false")
	actions.machine.current_state.transition_to(&"MOVE")
	actions.machine.transition_to(&"HURT")
	_check(actions.current == State.DEAD and not actions.can_attack(true) and not actions.get_permission(&"jump", player.action_profile), "Core 叶子和直接机器跳转也不能绕过死亡")
	CoreSystem.state_machine_manager.state_machine_started.connect(_on_machine_started)
	CoreSystem.state_machine_manager.stop_state_machine(actions.registration_id)
	_check(not CoreSystem.state_machine_manager.transition_state_machine(actions.registration_id, &"IDLE") and actions.current == State.DEAD, "停止再启动不能清除死亡标记")
	_check(machine_start_signals == 0, "被守卫拒绝的启动不发送虚假 started 通知")
	CoreSystem.state_machine_manager.start_state_machine(actions.registration_id, &"DEAD")
	_check(actions.machine.current_state.state_id == &"DEAD" and machine_start_signals == 1, "恢复机器只能恢复到死亡状态，实际成功才通知 started")
	CoreSystem.state_machine_manager.state_machine_started.disconnect(_on_machine_started)
#endregion
#region 重生、注销及 RefCounted 所属关系清理
func _verify_cleanup() -> void:
	var manager := CoreSystem.state_machine_manager
	var old_id := player.action_state.registration_id
	var old_leaf: BaseState = player.action_state.machine.current_state
	var old_machine: WeakRef = weakref(player.action_state.machine)
	demo.respawn()
	player = demo.player
	await _steps(8)
	_check(manager.get_state_machine(old_id) == null and old_leaf.state_machine == null and old_leaf.agent == null, "重生注销旧机器并断开叶子所属/agent 引用")
	_check(old_machine.get_ref() == null, "旧状态机没有 RefCounted 环引用泄漏")
	_check(player.action_state.registration_id != old_id and player.action_state.current == State.IDLE, "新实体拥有新机器和新死亡标记")
	for round_index in range(5):
		old_id = player.action_state.registration_id
		demo.respawn()
		player = demo.player
		await _steps(2)
		_check(manager.get_state_machine(old_id) == null and manager.get_all_state_machine_ids().size() == baseline_count + 3, "重复重生不积累注册机器")
	old_id = player.action_state.registration_id
	player.queue_free()
	await get_tree().process_frame
	_check(manager.get_state_machine(old_id) == null, "直接释放节点也注销动作机")
	session.clear_battle()
	await get_tree().process_frame
	_check(manager.get_all_state_machine_ids().size() == baseline_count, "清理战斗恢复 Core 注册数量")
#endregion
