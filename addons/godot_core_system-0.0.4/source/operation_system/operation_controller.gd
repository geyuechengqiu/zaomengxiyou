extends Node
class_name CoreOperationController

## 原生输入适配器与独立意图通道。状态/AI/网络只依赖意图 ID，不依赖键盘或手柄。
## 可继承覆盖 process_native_event；非原生来源可直接 submit_intent。

#region 配置、事件与运行状态
const Intent = preload("./operation_intent.gd")
const Profile = preload("./operation_profile.gd")
const Buffer = preload("./operation_buffer.gd")
signal intent_emitted(intent: Intent)
signal control_changed(available: bool, reasons: Array)

@export var profile: Profile
@export var device_filter: int = -1
@export var externally_driven: bool = false
@export var native_input_enabled: bool = true:
	set(value):
		native_input_enabled = value
		if not value:
			clear_native_sources()
var controller_id: StringName
var _strengths: Dictionary = {}
var _sources: Dictionary = {}
var input_time: float = 0.0
var _held_since: Dictionary = {}
var _press_orders: Dictionary = {}
var _last_tap: Dictionary = {}
var _double_held: Dictionary = {}
var _long_announced: Dictionary = {}
var _blocks: Dictionary = {}
var _native_down: Dictionary = {}
var _quarantined: Dictionary = {}
var _buffer := Buffer.new()
var _sequence: int = 0
var _resetting: bool = false


#endregion

#region 原生输入适配与 UI 优先
func _unhandled_input(event: InputEvent) -> void:
	process_native_event(event)


func _input(event: InputEvent) -> void:
	# 仅清理已持有来源的释放，绝不在 UI 之前接受新的按下。
	# 即使松键被 UI 吞掉，也不能令角色一直保持旧的移动意图。
	_record_native(event)
	_process_native(event, true)


func process_native_event(event: InputEvent) -> void:
	_record_native(event)
	_process_native(event, false)


func _record_native(event: InputEvent) -> void:
	if event.is_echo() or not event.is_action_type():
		return
	var token := _event_source(event)
	var down := absf(event.axis_value) > 0.2 if event is InputEventJoypadMotion else event.is_pressed()
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		# 滚轮是脉冲，没有系统松开事件，不能留下跨菜单的持有/隔离状态。
		down = false
	if down:
		_native_down[token] = true
		if not has_control():
			_quarantined[token] = true
	else:
		_native_down.erase(token)
		_quarantined.erase(token)
		## 释放按物理来源清理，不依赖改键后的映射或仍按住的修饰键。
		for intent in _sources.keys():
			var sources: Dictionary = _sources[intent]
			for source in sources.keys():
				if String(source).begins_with("native:") and String(source).ends_with("|" + token):
					_set_source(StringName(intent), source, 0.0, &"native", event.device, {})


func _process_native(event: InputEvent, releases_only: bool) -> void:
	if not native_input_enabled or profile == null or event.is_echo() or not event.is_action_type():
		return
	if device_filter >= 0 and event.device != device_filter:
		return
	for raw_intent in profile.bindings:
		var intent := StringName(raw_intent)
		for raw_action in profile.get_actions(intent):
			var action_name := StringName(raw_action)
			if not InputMap.has_action(action_name):
				continue
			var matches := event.is_action(action_name)
			if event is InputEventJoypadMotion:
				for binding in InputMap.action_get_events(action_name):
					if binding is InputEventJoypadMotion and binding.axis == event.axis:
						matches = true
			if not matches:
				continue
			# Godot 默认非精确匹配会忽略摇杆正负，反向必须显式精确匹配。
			var exact_match := event is InputEventJoypadMotion
			var value := event.get_action_strength(action_name, exact_match) if event.is_action_pressed(action_name, false, exact_match) else 0.0
			if releases_only and value > 0.0:
				continue
			if value > 0.0 and (not has_control() or _quarantined.has(_event_source(event))):
				continue
			var source := "native:%s|%s" % [action_name, _event_source(event)]
			_set_source(intent, source, value, &"native", event.device, {})
			if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
				_set_source(intent, source, 0.0, &"native", event.device, {})
				_native_down.erase(_event_source(event))


func _event_source(event: InputEvent) -> String:
	# 多键/多设备分别记账；松开一个来源不会清除其他仍按住的来源。
	var token := "action"
	if event is InputEventKey:
		token = "key:%d:%d" % [event.physical_keycode if event.physical_keycode != 0 else event.keycode, event.location]
	elif event is InputEventAction:
		token = "action:" + String(event.action)
	elif event is InputEventMouseButton:
		token = "mouse:%d" % event.button_index
	elif event is InputEventJoypadButton:
		token = "button:%d" % event.button_index
	elif event is InputEventJoypadMotion:
		token = "axis:%d" % event.axis
	return "%d:%s" % [event.device, token]


#endregion

#region 持续意图查询与非原生输入扩展
func get_strength(intent: StringName) -> float:
	return _strengths.get(intent, 0.0)


func is_pressed(intent: StringName) -> bool:
	return get_strength(intent) > 0.0


func get_axis(axis: StringName) -> float:
	if profile == null or not profile.axes.has(axis):
		return 0.0
	var mapping = profile.axes[axis]
	if not mapping is Dictionary:
		return 0.0
	var positive := StringName(mapping.get("positive", ""))
	var negative := StringName(mapping.get("negative", ""))
	var plus := get_strength(positive)
	var minus := get_strength(negative)
	if mapping.get("opposites", "") == "last_pressed" and plus > 0.0 and minus > 0.0:
		return plus if _press_orders.get(positive, 0) > _press_orders.get(negative, 0) else -minus
	return clampf(plus - minus, -1.0, 1.0)


func get_double_tap_direction(axis: StringName) -> int:
	if profile == null or not profile.axes.has(axis):
		return 0
	var mapping: Dictionary = profile.axes[axis]
	var direction := int(signf(get_axis(axis)))
	var action := StringName(mapping.get("positive" if direction > 0 else "negative", ""))
	return direction if direction != 0 and _double_held.has(action) and is_pressed(action) else 0

## 仅清除指定轴的奔跑识别，保留其他操作缓存与按键状态。
func clear_double_tap_axis(axis: StringName) -> void:
	if profile == null or not profile.axes.has(axis): return
	for key in ["positive", "negative"]:
		var action := StringName(profile.axes[axis].get(key, ""))
		_double_held.erase(action)
		_last_tap.erase(action)


func submit_intent(intent: StringName, strength: float = 1.0, origin: StringName = &"virtual", payload: Dictionary = {}) -> void:
	# 自定义意图不要求 InputMap 中存在同名动作；同一 origin 的新值替换旧值。
	if has_control():
		_set_source(intent, "virtual:%s" % origin, strength, origin, -1, payload)


func pulse_intent(intent: StringName, origin: StringName = &"virtual", payload: Dictionary = {}) -> void:
	submit_intent(intent, 1.0, origin, payload)
	submit_intent(intent, 0.0, origin, payload)


func set_profile(new_profile: Profile) -> void:
	reset(&"profile_changed")
	profile = new_profile


func clear_native_sources() -> void:
	# 禁用原生适配器时只释放原生来源，不影响 AI/触屏等虚拟来源的持续意图。
	for intent in _sources.keys():
		var sources: Dictionary = _sources[intent]
		for source in sources.keys():
			if String(source).begins_with("native:"):
				_set_source(StringName(intent), source, 0.0, &"reset", -1, {"cancelled": true})
	_buffer.clear()
	_last_tap.clear()
	_double_held.clear()


func reset(reason: StringName = &"reset") -> void:
	if _resetting:
		return
	_resetting = true
	for token in _native_down:
		_quarantined[token] = true
	var held := _strengths.duplicate()
	var times := _held_since.duplicate()
	_sources.clear()
	_strengths.clear()
	_held_since.clear()
	_press_orders.clear()
	_last_tap.clear()
	_double_held.clear()
	_long_announced.clear()
	_buffer.clear()
	for action in held:
		_emit_intent(StringName(action), 0.0, &"reset", -1, {"just_pressed": false, "cancelled": true, "reason": reason}, Intent.Phase.RELEASED, input_time - float(times.get(action, input_time)))
	_resetting = false


#endregion

#region 聚合来源与语义事件生成
func _set_source(intent: StringName, source: String, value: float, origin: StringName, device: int, payload: Dictionary) -> void:
	if intent.is_empty() or not is_finite(value) or _resetting:
		return
	value = clampf(value, 0.0, 1.0)
	var sources: Dictionary = _sources.get(intent, {})
	if value > 0.0:
		sources[source] = value
	else:
		sources.erase(source)
	var strength := 0.0
	for current_value in sources.values():
		strength = maxf(strength, float(current_value))
	if sources.is_empty():
		_sources.erase(intent)
	else:
		_sources[intent] = sources
	var previous := get_strength(intent)
	if is_equal_approx(previous, strength):
		return
	var phase := Intent.Phase.CHANGED
	var held := input_time - float(_held_since.get(intent, input_time))
	var data := payload.duplicate(true)
	data["just_pressed"] = previous <= 0.0 and strength > 0.0
	if strength > 0.0:
		_strengths[intent] = strength
		if previous <= 0.0:
			phase = Intent.Phase.PRESSED
			_held_since[intent] = input_time
			_press_orders[intent] = _sequence + 1
			held = 0.0
			if profile != null and profile.double_tap_intents.has(intent):
				var double_tap := _last_tap.has(intent) and input_time - float(_last_tap[intent]) < profile.double_tap_seconds
				for other in profile.double_tap_intents:
					if other != intent:
						_last_tap.erase(other)
						_double_held.erase(other)
				data["double_tap"] = double_tap
				if double_tap:
					_double_held[intent] = true
					_last_tap.erase(intent)
				else:
					_last_tap[intent] = input_time
	else:
		_strengths.erase(intent)
		_held_since.erase(intent)
		_long_announced.erase(intent)
		_double_held.erase(intent)
		phase = Intent.Phase.RELEASED
	# 强度变化也通知消费者；不能将摇杆强度调整重复解释为跳跃/攻击按下。
	_emit_intent(intent, strength, origin, device, data, phase, held)


func _emit_intent(intent: StringName, strength: float, origin: StringName, device: int, payload: Dictionary, phase: Intent.Phase = Intent.Phase.PRESSED, held: float = 0.0) -> void:
	_sequence += 1
	var event := Intent.new()
	event.action = intent
	event.strength = strength
	event.pressed = strength > 0.0
	event.origin = origin
	event.device = device
	event.payload = payload
	event.payload["held_intents"] = _strengths.keys().duplicate()
	event.phase = phase
	event.sequence = _sequence
	event.input_time = input_time
	event.held_seconds = held
	if phase == Intent.Phase.PRESSED and profile != null and profile.buffered_intents.has(intent):
		_buffer.append(event, profile.buffer_seconds, profile.buffer_capacity)
	intent_emitted.emit(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		set_control_blocked(&"focus_lost", true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		set_control_blocked(&"focus_lost", false)
	elif what == NOTIFICATION_PAUSED:
		set_control_blocked(&"node_paused", true)
	elif what == NOTIFICATION_UNPAUSED:
		set_control_blocked(&"node_paused", false)


func _exit_tree() -> void:
	reset(&"exit_tree")
#endregion

#region 输入时间、长按与消费缓存
func _physics_process(delta: float) -> void:
	if not externally_driven:
		advance_input(delta / Engine.time_scale if Engine.time_scale > 0.0 else 0.0)

func advance_input(delta: float) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	if is_inside_tree():
		set_control_blocked(&"tree_paused", get_tree().paused)
	input_time += delta
	_buffer.clean_expired(input_time)
	if delta <= 0.0 or not has_control():
		return
	for action in _strengths.keys():
		if not has_control() or not is_pressed(action):
			continue
		var held := input_time - float(_held_since.get(action, input_time))
		var data := {"just_pressed": false, "long_press_started": false}
		if profile != null and profile.long_press_seconds > 0.0 and held >= profile.long_press_seconds:
			data["long_pressed"] = true
			if not _long_announced.has(action):
				_long_announced[action] = true
				data["long_press_started"] = true
		_emit_intent(StringName(action), get_strength(action), &"held", -1, data, Intent.Phase.HELD, held)

func peek_buffered_intents() -> Array[CoreOperationIntent]:
	return _buffer.peek(input_time)

func consume_buffered_intent(sequence: int) -> bool:
	_buffer.clean_expired(input_time)
	return _buffer.consume(sequence)

func clear_buffered_intents(action: StringName = &"") -> void:
	_buffer.clear(action)
#endregion
#region 控制权与互不覆盖的阻断原因
func has_control() -> bool:
	return _blocks.is_empty() and not _resetting

func get_control_blocks() -> Array:
	return _blocks.keys().duplicate()

func set_control_blocked(reason: StringName, blocked: bool) -> void:
	if reason.is_empty() or _blocks.has(reason) == blocked:
		return
	if blocked:
		_blocks[reason] = true
		reset(reason)
	else:
		_blocks.erase(reason)
	control_changed.emit(has_control(), get_control_blocks())
#endregion
