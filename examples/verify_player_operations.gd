extends Node
#region 验收夹具
class CharacterBranches extends BattlePlayerOperations:
	var consumed: Array[StringName] = []
	var phases: Array[CoreOperationIntent] = []
	var cancellations: Array[StringName] = []
	var order: Array[String] = []
	func _handle_character_intent(intent: CoreOperationIntent) -> Result:
		return Result.ACCEPTED if intent.action == &"character_special" else Result.UNAVAILABLE
	func _after_common_intent(intent: CoreOperationIntent, _result: Result) -> void:
		consumed.append(intent.action)
		order.append("pressed:" + String(intent.action))
	func _handle_character_phase(intent: CoreOperationIntent) -> void:
		phases.append(intent.copy_intent())
		order.append(intent.get_phase_name() + ":" + String(intent.action))
	func _handle_cancelled_intent(intent: CoreOperationIntent) -> void:
		cancellations.append(intent.action)

class GuiSink extends Control:
	var received: int = 0
	func _gui_input(_event: InputEvent) -> void:
		received += 1
		accept_event()

const PROFILE := preload("res://data/controls/player_operations.tres")
var failures: Array[String] = []
var checks: int = 0
var controller: CoreOperationController
var events: Array[CoreOperationIntent] = []
var demo: Node2D
var session: BattleSession
var results: Array[Dictionary] = []
var original_config_path: String
#endregion
#region 入口与辅助
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	original_config_path = CoreSystem.config_manager.config_path
	ProjectSettings.set_setting(CoreSystem.config_manager.SETTING_CONFIG_PATH, "user://operation-verification.cfg")
	CoreSystem.config_manager.reset_config()
	controller = CoreSystem.operation_manager.create_controller(&"verification/input", PROFILE.duplicate(true))
	controller.externally_driven = true
	add_child(controller)
	controller.set_process_input(false)
	controller.set_process_unhandled_input(false)
	controller.intent_emitted.connect(func(intent): events.append(intent.copy_intent()))
	_verify_edges_and_buffer()
	_verify_directions()
	_verify_sources()
	_verify_control_and_remapping()
	await _verify_role_and_gui()
	CoreSystem.operation_manager.bindings.reset_profile(PROFILE, false)
	ProjectSettings.set_setting(CoreSystem.config_manager.SETTING_CONFIG_PATH, original_config_path)
	CoreSystem.config_manager.load_config()
	controller.queue_free()
	await get_tree().process_frame
	_check(CoreSystem.operation_manager.get_controller(&"verification/input") == null, "退出注销弱引用控制器")
	if failures.is_empty():
		print("PASS player operations: %d checks; edges, holds, buffering, double taps, remapping, UI/focus/ownership and real GAS/physics" % checks)
		get_tree().quit(0)
	else:
		for message in failures:
			push_error(message)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _key(code: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func _native(code: int, pressed: bool = true, echo: bool = false) -> void:
	controller.process_native_event(_key(code, pressed, echo))

func _count(action: StringName, phase: CoreOperationIntent.Phase) -> int:
	return events.filter(func(event): return event.action == action and event.phase == phase).size()

func _fresh() -> void:
	for reason in controller.get_control_blocks():
		controller.set_control_blocked(StringName(reason), false)
	for code in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT, KEY_J, KEY_K, KEY_C, KEY_V, KEY_SHIFT]:
		_native(code, false)
	controller.reset()
	events.clear()

func _send(code: int, pressed: bool = true) -> void:
	Input.parse_input_event(_key(code, pressed))
	Input.flush_buffered_events()
	await get_tree().process_frame

func _step(delta: float, count: int = 1) -> void:
	for index in range(count):
		await get_tree().physics_frame
		session.advance_physics(delta)

func _on_event(id: String, payload: Array) -> void:
	if payload.size() != 1 or not payload[0] is Dictionary or payload[0].get("battle_id") != session.battle_id:
		return
	if id == "battle.operation_result":
		results.append(payload[0])
#endregion
#region 短按、长按、连按与可消费缓存
func _verify_edges_and_buffer() -> void:
	for raw_intent in PROFILE.bindings:
		var intent := StringName(raw_intent)
		var action := StringName(PROFILE.get_actions(intent)[0])
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "默认动作已安装：" + String(intent))
		var event := InputEventAction.new()
		event.action = action
		event.pressed = true
		event.strength = 1.0
		controller.process_native_event(event)
		event.pressed = false
		controller.process_native_event(event)
		_check(_count(intent, CoreOperationIntent.Phase.PRESSED) == 1 and _count(intent, CoreOperationIntent.Phase.RELEASED) == 1, "每个操作有独立按下和松开：" + String(intent))
	_fresh()
	_native(KEY_J)
	_native(KEY_J, false)
	_check(_count(&"attack", CoreOperationIntent.Phase.PRESSED) == 1 and _count(&"attack", CoreOperationIntent.Phase.RELEASED) == 1, "同 tick 短按仍保留两个边沿")
	var pending := controller.peek_buffered_intents()
	_check(pending.size() == 1 and not controller.is_pressed(&"attack"), "松键不丢弃待消费的短按")
	pending[0].payload["tampered"] = true
	_check(not controller.peek_buffered_intents()[0].payload.has("tampered"), "缓存读取是快照，消费者不能修改队列")
	_check(controller.consume_buffered_intent(pending[0].sequence) and not controller.consume_buffered_intent(pending[0].sequence), "同一序列只消费一次")
	for index in range(3):
		_native(KEY_J)
		_native(KEY_J, false)
	pending = controller.peek_buffered_intents()
	_check(pending.size() == 3 and pending[0].sequence < pending[1].sequence and pending[1].sequence < pending[2].sequence, "三次连按保留三次独立请求")
	controller.consume_buffered_intent(pending[1].sequence)
	pending = controller.peek_buffered_intents()
	_check(pending.size() == 2, "消费其中一次不抹掉前后连按")
	controller.advance_input(0.201)
	_check(controller.peek_buffered_intents().is_empty(), "按真实输入时间过期")
	controller.profile.buffer_capacity = 2
	for index in range(3):
		controller.pulse_intent(&"attack")
	_check(controller.peek_buffered_intents().size() == 2, "队列满时丢最旧请求")
	controller.profile.buffer_capacity = 16
	_fresh()
	_native(KEY_J)
	_native(KEY_J, true, true)
	controller.advance_input(0.15)
	controller.advance_input(0.16)
	controller.advance_input(0.1)
	_native(KEY_J, false)
	_check(_count(&"attack", CoreOperationIntent.Phase.PRESSED) == 1 and _count(&"attack", CoreOperationIntent.Phase.HELD) == 3, "长按与 OS echo 不重复生成按下")
	_check(events.filter(func(event): return event.payload.get("long_press_started", false)).size() == 1, "长按阈值只触发一次")
	var released: CoreOperationIntent = events.back()
	_check(released.is_intent_released(&"attack") and is_equal_approx(released.held_seconds, 0.41), "松开携带完整持有时长")
	_check(events.filter(func(event): return event.is_intent_pressed(&"attack")).size() == 1, "旧按下 API 不把 held 当成新按下")
#endregion
#region 双击方向与多来源聚合
func _verify_directions() -> void:
	_fresh()
	_native(KEY_A)
	_native(KEY_A, false)
	controller.advance_input(0.4)
	_native(KEY_A)
	_check(controller.get_double_tap_direction(&"move") == -1 and events.back().payload.get("double_tap", false), "原版小于 0.5 秒的同方向双击")
	controller.advance_input(1.0)
	_check(controller.get_double_tap_direction(&"move") == -1, "第二次按住期间保持双击奔跑")
	_native(KEY_A, false)
	_check(controller.get_double_tap_direction(&"move") == 0, "松开第二次按键停止双击奔跑")
	_fresh()
	_native(KEY_D)
	_native(KEY_D, false)
	controller.advance_input(0.51)
	_native(KEY_D)
	_check(controller.get_double_tap_direction(&"move") == 0, "超时不是双击")
	_fresh()
	_native(KEY_A)
	_native(KEY_A, false)
	_native(KEY_D)
	_native(KEY_D, false)
	_native(KEY_A)
	_check(controller.get_double_tap_direction(&"move") == 0, "左右交替不误判同方向双击")
	_native(KEY_D)
	_check(controller.get_axis(&"move") == 1.0, "相反方向同时按住采用后按优先")
	_native(KEY_D, false)
	_check(controller.get_axis(&"move") == -1.0, "松开后按方向恢复另一个仍持有方向")
	_fresh()
	_native(KEY_A)
	_native(KEY_LEFT)
	_native(KEY_A, false)
	_check(controller.get_axis(&"move") == -1.0 and _count(&"move_left", CoreOperationIntent.Phase.PRESSED) == 1, "A 与左方向键聚合，不重复按下、不提前释放")
	_native(KEY_LEFT, false)
	_check(controller.get_axis(&"move") == 0.0, "最后一个来源释放后停止")

func _verify_sources() -> void:
	_fresh()
	_native(KEY_J)
	controller.submit_intent(&"attack", 0.7, &"touch")
	_native(KEY_J, false)
	_check(is_equal_approx(controller.get_strength(&"attack"), 0.7), "原生释放保留触屏来源")
	_check(_count(&"attack", CoreOperationIntent.Phase.CHANGED) == 1 and _count(&"attack", CoreOperationIntent.Phase.PRESSED) == 1, "强度变化不产生第二次攻击边沿")
	controller.native_input_enabled = false
	_check(controller.is_pressed(&"attack"), "禁用原生输入保留虚拟输入")
	controller.submit_intent(&"attack", 0.0, &"touch")
	controller.native_input_enabled = true
	_fresh()
	controller.device_filter = 3
	var event := _key(KEY_J)
	event.device = 2
	controller.process_native_event(event)
	_check(not controller.is_pressed(&"attack"), "设备过滤阻止其他手柄/来源")
	event.device = 3
	controller.process_native_event(event)
	_check(controller.is_pressed(&"attack"), "设备过滤接受指定来源")
	event.pressed = false
	controller.process_native_event(event)
	controller.device_filter = -1
	var negative := InputEventJoypadMotion.new()
	negative.axis = JOY_AXIS_LEFT_X
	negative.axis_value = -1.0
	var positive := negative.duplicate() as InputEventJoypadMotion
	positive.axis_value = 1.0
	InputMap.action_add_event(&"battle_player.left", negative)
	InputMap.action_add_event(&"battle_player.right", positive)
	negative = negative.duplicate() as InputEventJoypadMotion
	negative.axis_value = -0.8
	controller.process_native_event(negative)
	_check(controller.get_axis(&"move") < 0.0, "摇杆负方向产生左移")
	negative.axis_value = 0.9
	controller.process_native_event(negative)
	_check(controller.get_axis(&"move") > 0.0 and not controller.is_pressed(&"move_left"), "摇杆直接反向时清理旧方向")
	negative.axis_value = 0.1
	controller.process_native_event(negative)
	_check(controller.get_axis(&"move") == 0.0, "摇杆死区释放")
	CoreSystem.operation_manager.bindings.reset_profile(PROFILE, false)
	_fresh()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	CoreSystem.operation_manager.bindings.set_binding(&"battle_player.attack", wheel, false)
	controller.set_control_blocked(&"menu", true)
	controller.process_native_event(wheel)
	controller.set_control_blocked(&"menu", false)
	controller.process_native_event(wheel)
	_check(_count(&"attack", CoreOperationIntent.Phase.PRESSED) == 1, "菜单中的滚轮脉冲不留下永远等不到松键的隔离状态")
	_check(not controller.is_pressed(&"attack") and _count(&"attack", CoreOperationIntent.Phase.RELEASED) == 1, "滚轮操作自动按下和松开，不留下持续攻击")
	CoreSystem.operation_manager.bindings.reset_profile(PROFILE, false)
#endregion
#region 控制权、失焦、捕获与持久化
func _verify_control_and_remapping() -> void:
	_fresh()
	_native(KEY_D)
	_native(KEY_J)
	controller.set_control_blocked(&"menu", true)
	_check(controller.get_axis(&"move") == 0.0 and controller.peek_buffered_intents().is_empty(), "菜单同步释放移动并清空缓存")
	_check(events.filter(func(event): return event.payload.get("cancelled", false)).size() == 2, "取消通知每个持有意图")
	controller.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	controller.set_control_blocked(&"menu", false)
	controller.pulse_intent(&"attack", &"ai")
	_check(not controller.has_control() and not controller.is_pressed(&"attack"), "关闭菜单不能覆盖失焦控制权，虚拟输入也被阻断")
	controller.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_native(KEY_D)
	_check(not controller.is_pressed(&"move_right"), "恢复焦点不能接续旧持有键")
	_native(KEY_D, false)
	_native(KEY_D)
	_check(controller.is_pressed(&"move_right"), "释放后重新按下恢复控制")
	_fresh()
	controller.set_control_blocked(&"ownership", true)
	controller.set_control_blocked(&"console", true)
	controller.set_control_blocked(&"console", false)
	_check(not controller.has_control(), "关闭控制台不抢回已让出的控制权")
	controller.set_control_blocked(&"ownership", false)
	var service := CoreSystem.operation_manager.bindings
	_check(not service.set_binding(&"battle_player.attack", _key(KEY_K), false), "冲突键拒绝覆盖跳跃")
	_check(not service.set_binding(&"battle_player.attack", _key(KEY_F1), false), "拒绝占用场景调试快捷键")
	_check(service.start_remap(controller, &"attack", false) and not controller.has_control(), "捕获新键期间撤回角色控制")
	_check(service.capture_event(_key(KEY_K)) and service.is_remapping(), "冲突保持捕获并等待另一个键")
	service.capture_event(_key(KEY_ESCAPE))
	_check(not service.is_remapping() and controller.has_control(), "Esc 取消捕获并恢复仅捕获占用的控制权")
	_check(service.start_remap(controller, &"attack", true), "开始可持久化重映射")
	service.capture_event(_key(KEY_C))
	_check(not service.is_remapping() and InputMap.event_is_action(_key(KEY_C), &"battle_player.attack"), "捕获 C 修改 InputMap")
	_check(FileAccess.file_exists(CoreSystem.config_manager.config_path), "绑定保存到隔离验收配置")
	_native(KEY_J, false)
	_native(KEY_J)
	_check(not controller.is_pressed(&"attack"), "旧 J 不再触发普攻")
	_native(KEY_C)
	_check(controller.is_pressed(&"attack"), "新 C 仍产生 attack 语义")
	_native(KEY_C, false)
	CoreSystem.config_manager.load_config()
	service.reset_profile(PROFILE, false)
	var restored := CoreOperationBindings.new()
	add_child(restored)
	_check(restored.install_profile(PROFILE) and InputMap.event_is_action(_key(KEY_C), &"battle_player.attack"), "重新加载用户配置恢复绑定")
	restored.queue_free()
	service.reset_profile(PROFILE, false)
#endregion
#region 实际角色、GAS、平台物理、UI 与角色分支
func _verify_role_and_gui() -> void:
	demo = load("res://examples/wukong_platform_demo.tscn").instantiate()
	add_child(demo)
	demo.set_physics_process(false)
	session = demo.session
	session.damage_strategy = SimpleDamageLogic.new()
	session.set_physics_process(false)
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	await _step(1.0 / 60.0, 6)
	var player: BattleEntity2D = demo.player
	var controls: CoreOperationController = demo.operations.controller
	# 这里专门验收未装配语义槽；角色现已默认装配五个真实技能。
	demo.operations.ability_slots.clear()
	await _send(KEY_J)
	await _send(KEY_J, false)
	await _step(0.016)
	_check(player.action_state.current == BattleActionState2D.State.ATTACK, "短按在真实角色启动 GAS 普攻")
	_check(results.filter(func(result): return result.intent == &"attack" and result.result == "ACCEPTED").size() == 1, "一次短按只消费一次")
	await _step(0.2)
	await _send(KEY_J)
	await _send(KEY_J, false)
	await _step(0.1)
	_check(demo.player.combo.queued_next and controls.peek_buffered_intents().is_empty(), "恢复前提前按攻击已预约下一连击段，只消费本次序列")
	await _step(0.03, 2)
	_check(results.filter(func(result): return result.intent == &"attack" and result.result == "ACCEPTED").size() == 2, "恢复后消费缓存连按一次")
	await _step(0.35, 2)
	var before := results.size()
	await _send(KEY_J)
	await _step(0.1, 6)
	await _send(KEY_J, false)
	_check(results.size() == before + 1, "持续按住不会自动重复普攻")
	await _step(0.35)
	_check(CoreSystem.operation_manager.bindings.set_binding(&"battle_player.attack", _key(KEY_C), false), "运行中直接改键")
	await _send(KEY_J)
	await _send(KEY_J, false)
	await _step(0.016)
	_check(player.action_state.current != BattleActionState2D.State.ATTACK, "真实角色不再响应旧键")
	await _send(KEY_C)
	await _send(KEY_C, false)
	await _step(0.016)
	_check(player.action_state.current == BattleActionState2D.State.ATTACK, "不修改角色代码即可使用 C 普攻")
	await _step(0.35, 2)
	var sink := GuiSink.new()
	sink.focus_mode = Control.FOCUS_ALL
	sink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gui_layer := CanvasLayer.new()
	gui_layer.layer = 40
	demo.add_child(gui_layer)
	gui_layer.add_child(sink)
	sink.grab_focus()
	await _send(KEY_C)
	_check(sink.received > 0 and not controls.is_pressed(&"attack"), "普通 UI 消费的新按键不进入角色")
	await _send(KEY_C, false)
	sink.release_focus()
	await _send(KEY_D)
	await _step(0.016)
	_check(player.move_axis > 0.0, "实际方向意图驱动平台移动")
	_check(player.action_state.machine.get_current_state_name() == &"MOVE" and player.animation.get_current_action() == &"move", "Core 当前叶子接收方向按下并播放行走")
	sink.grab_focus()
	await _send(KEY_D, false)
	await _step(0.016)
	_check(player.move_axis == 0.0, "UI 吞掉松键也能释放既有移动")
	_check(player.action_state.machine.get_current_state_name() == &"IDLE" and player.animation.get_current_action() == &"idle", "UI 吞掉松键后同一战斗 tick 返回待机状态与动画")
	sink.queue_free()
	gui_layer.queue_free()
	await get_tree().process_frame
	await _verify_action_intents(player, controls)
	await _send(KEY_ESCAPE)
	await _send(KEY_ESCAPE, false)
	_check(demo.operation_menu.visible and not controls.has_control() and session.clock.paused, "Esc 菜单同时交出控制和暂停战斗")
	before = results.size()
	await _send(KEY_C)
	await _step(0.016)
	_check(results.size() == before and controls.peek_buffered_intents().is_empty(), "菜单操作不会同时触发攻击")
	_check(CoreSystem.operation_manager.bindings.start_remap(controls, &"attack", false), "真实菜单启动改键捕获")
	await _send(KEY_B)
	_check(not CoreSystem.operation_manager.bindings.is_remapping() and InputMap.event_is_action(_key(KEY_B), &"battle_player.attack") and controls.peek_buffered_intents().is_empty(), "捕获输入只改键、不进入攻击缓存")
	await _send(KEY_B, false)
	CoreSystem.operation_manager.bindings.set_binding(&"battle_player.attack", _key(KEY_C), false)
	controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	demo.operation_menu.set_open(false)
	_check(not controls.has_control(), "菜单关闭时失焦仍保留阻断")
	controls.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await _send(KEY_C, false)
	await _send(KEY_C)
	await _send(KEY_C, false)
	await _step(0.016)
	_check(player.action_state.current == BattleActionState2D.State.ATTACK, "焦点恢复、释放再按后正常普攻")
	await _step(0.35, 2)
	demo.operations.ability_slots[&"skill_1"] = &"sunwukong_attack1"
	await _send(KEY_Y)
	await _send(KEY_Y, false)
	await _step(0.016)
	_check(player.action_state.current == BattleActionState2D.State.ATTACK and results.back().intent == &"skill_1", "技能槽路由到配置的 GAS 技能 ID")
	await _step(0.35, 2)
	for code in [KEY_H, KEY_SPACE, KEY_U, KEY_I, KEY_O, KEY_L, KEY_Q, KEY_E, KEY_F, KEY_Z, KEY_R, KEY_P]:
		await _send(code)
		await _send(code, false)
		await _step(0.016)
		_check(results.back().result == "UNAVAILABLE", "未装配槽位只报告意图，不伪造技能：" + OS.get_keycode_string(code))
	await _send(KEY_K)
	await _send(KEY_K, false)
	await _step(0.016)
	_check(player.velocity.y < 0.0 and player.action_state.current == BattleActionState2D.State.TAKEOFF, "K 意图通过状态许可执行真实起跳")
	player.position = Vector2(510, 646)
	player.velocity.y = 200.0
	player.motion.jumps_used = 2
	await _send(KEY_K)
	await _send(KEY_K, false)
	await _step(0.03)
	_check(player.action_state.grounded and not controls.peek_buffered_intents().is_empty(), "落地前短按跳跃在接触地面时仍保留")
	await _step(0.016)
	_check(player.velocity.y < 0.0 and controls.peek_buffered_intents().is_empty(), "下一 tick 落地许可消费预输入跳跃")
	player.position = Vector2(510, 650)
	player.velocity = Vector2.ZERO
	await _step(0.016, 2)
	var combat_time := session.clock.elapsed
	var input_time := controls.input_time
	session.set_time_scale(0.5)
	await _step(0.1)
	_check(is_equal_approx(controls.input_time - input_time, 0.1) and is_equal_approx(session.clock.elapsed - combat_time, 0.05), "输入与长按不受战斗慢动作缩放")
	session.set_time_scale(1.0)
	session.request_hit_stop(0.3)
	await _send(KEY_C)
	await _send(KEY_C, false)
	await _step(0.1, 3)
	_check(controls.peek_buffered_intents().is_empty(), "长受击停顿中的按键按真实时间过期，不恢复后偷放攻击")
	get_tree().paused = true
	await _step(0.016)
	_check(not controls.has_control(), "SceneTree 暂停阻断 Always 会话中的控制器")
	get_tree().paused = false
	await _step(0.016)
	_check(controls.has_control(), "SceneTree 恢复只撤销暂停原因")
	# 角色子类在公共操作后追加分支；不更改 Core 控制器。
	var old_operations: BattlePlayerOperations = demo.operations
	var old_id := old_operations.controller.controller_id
	player.remove_child(old_operations)
	old_operations.free()
	_check(CoreSystem.operation_manager.get_controller(old_id) == null, "换控制者注销旧通道")
	var branches := CharacterBranches.new()
	branches.operation_profile = PROFILE.duplicate(true)
	branches.operation_profile.bind_intent(&"character_special", [&"verification.character_special"])
	branches.operation_profile.default_keys[&"verification.character_special"] = ["V"]
	branches.operation_profile.buffered_intents.append(&"character_special")
	player.operations = branches
	demo.operations = branches
	var replacement_controller := CoreOperationController.new()
	replacement_controller.name = "OperationController"
	branches.add_child(replacement_controller)
	player.add_child(branches)
	demo.operation_menu.bind_controller(branches.controller)
	await _send(KEY_V)
	await _send(KEY_V, false)
	await _step(0.016)
	_check(branches.consumed.count(&"character_special") == 1, "角色可追加独有语义分支")
	_check(branches.order.slice(0, 2) == ["pressed:character_special", "released:character_special"], "同帧短按给角色专属分支先按下再松开，蓄力不倒序")
	await _send(KEY_C)
	await _step(0.1)
	await _send(KEY_C, false)
	await _step(0.016)
	_check(branches.consumed.count(&"attack") == 1, "公共操作先执行，角色后置钩子只执行一次")
	_check(branches.phases.any(func(event): return event.is_intent_held(&"attack")) and branches.phases.any(func(event): return event.is_intent_released(&"attack")), "角色扩展收到持有和正常释放")
	await _send(KEY_D)
	await _step(0.016)
	branches.enabled = false
	_check(player.move_axis == 0.0 and branches.cancellations.has(&"move_right"), "让出控制权同步停止移动与专属蓄力")
	await _send(KEY_D, false)
	branches.enabled = true
	player.receive_damage(10000)
	await _step(0.016)
	_check(not branches.controller.has_control(), "死亡角色撤回操作控制权")
	CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	session.clear_battle()
	demo.queue_free()
	await get_tree().process_frame
#endregion
#region 意图驱动 Core 状态、释放与攻击锁定
func _verify_action_intents(player: BattleEntity2D, controls: CoreOperationController) -> void:
	var State = BattleActionState2D.State
	controls.reset(&"verification")
	controls.submit_intent(&"move_left")
	controls.submit_intent(&"move_right")
	await _step(1.0 / 60.0)
	_check(player.move_axis == 1.0 and player.action_state.current == State.MOVE, "两个方向按下由意图快照保持后按优先")
	controls.submit_intent(&"move_right", 0.0)
	await _step(1.0 / 60.0)
	_check(player.move_axis == -1.0 and player.action_state.current == State.MOVE, "松开后按方向恢复另一个持有方向，不能误回待机")
	controls.submit_intent(&"move_left", 0.0)
	await _step(1.0 / 60.0)
	_check(player.action_state.current == State.IDLE and player.animation.get_current_action() == &"idle", "全部方向释放后状态和动画返回待机")
	controls.reset(&"verification")
	controls.submit_intent(&"move_right")
	await _step(1.0 / 60.0)
	controls.submit_intent(&"move_right", 0.0)
	await _step(1.0 / 60.0)
	controls.submit_intent(&"move_right")
	await _step(1.0 / 60.0)
	_check(player.action_state.current == State.RUN and player.animation.get_current_action() == &"run", "同方向双击意图进入 Core RUN")
	controls.submit_intent(&"move_right", 0.0)
	await _step(1.0 / 60.0)
	_check(player.action_state.current == State.IDLE and not player.running, "松开双击方向同时清奔跑并返回待机")
	controls.submit_intent(&"move_right", 0.3)
	await _step(1.0 / 60.0)
	controls.submit_intent(&"move_right", 0.6)
	await _step(1.0 / 60.0)
	_check(is_equal_approx(player.move_axis, 0.6), "模拟方向 CHANGED 意图更新强度")
	controls.submit_intent(&"move_right", 0.0)
	controls.pulse_intent(&"attack")
	controls.submit_intent(&"move_left")
	var at := player.position
	await _step(1.0 / 60.0)
	_check(player.action_state.current == State.ATTACK and absf(player.position.x - at.x) < 0.1, "当前 ATTACK 叶子接收方向但按权限阻止行走")
	controls.submit_intent(&"move_left", 0.0)
	await _step(1.0 / 60.0)
	_check(player.action_state.current == State.ATTACK and player.move_axis == 0.0, "攻击中松方向清意图但不能打断攻击为待机")
	await _step(1.0 / 60.0, 24)
	_check(player.action_state.current == State.IDLE and player.animation.get_current_action() == &"idle", "攻击结束读取已释放的意图恢复待机")
	controls.submit_intent(&"move_right")
	await _step(1.0 / 60.0)
	controls.set_control_blocked(&"verification_menu", true)
	_check(player.move_axis == 0.0 and player.action_state.current == State.IDLE and player.animation.get_current_action() == &"idle", "菜单撤销控制同步释放 Core 移动状态及动画，不依赖后续战斗 tick")
	controls.set_control_blocked(&"verification_menu", false)
#endregion
