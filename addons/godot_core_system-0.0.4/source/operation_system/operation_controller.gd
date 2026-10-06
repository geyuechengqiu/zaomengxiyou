extends Node
class_name CoreOperationController

## 原生输入适配器与独立意图通道。状态/AI/网络只依赖意图 ID，不依赖键盘或手柄。
## 可继承覆盖 process_native_event；非原生来源可直接 submit_intent。

#region 配置、事件与运行状态
const Intent = preload("./operation_intent.gd")
const Profile = preload("./operation_profile.gd")
signal intent_emitted(intent: Intent)

@export var profile: Profile
@export var device_filter: int = -1
@export var native_input_enabled: bool = true:
	set(value):
		native_input_enabled = value
		if not value:
			clear_native_sources()
var controller_id: StringName
var _strengths: Dictionary = {}
var _sources: Dictionary = {}


#endregion

#region 原生输入适配与 UI 优先
func _unhandled_input(event: InputEvent) -> void:
	process_native_event(event)


func _input(event: InputEvent) -> void:
	# 仅清理已持有来源的释放，绝不在 UI 之前接受新的按下。
	# 即使松键被 UI 吞掉，也不能令角色一直保持旧的移动意图。
	_process_native(event, true)


func process_native_event(event: InputEvent) -> void:
	_process_native(event, false)


func _process_native(event: InputEvent, releases_only: bool) -> void:
	if not native_input_enabled or profile == null or event.is_echo() or not event.is_action_type():
		return
	if device_filter >= 0 and event.device != device_filter:
		return
	for raw_intent in profile.bindings:
		var intent := StringName(raw_intent)
		for raw_action in profile.get_actions(intent):
			var action_name := StringName(raw_action)
			if not InputMap.has_action(action_name) or not event.is_action(action_name):
				continue
			var value := event.get_action_strength(action_name) if event.is_action_pressed(action_name) else 0.0
			if releases_only and value > 0.0:
				continue
			_set_source(intent, "native:%s:%s" % [action_name, _event_source(event)], value, &"native", event.device, {})


func _event_source(event: InputEvent) -> String:
	# 多键/多设备分别记账；松开一个来源不会清除其他仍按住的来源。
	var token := "action"
	if event is InputEventKey:
		token = "key:%d:%d:%d" % [event.physical_keycode, event.keycode, event.location]
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
	return clampf(get_strength(StringName(mapping.get("positive", ""))) - get_strength(StringName(mapping.get("negative", ""))), -1.0, 1.0)


func submit_intent(intent: StringName, strength: float = 1.0, origin: StringName = &"virtual", payload: Dictionary = {}) -> void:
	# 自定义意图不要求 InputMap 中存在同名动作；同一 origin 的新值替换旧值。
	_set_source(intent, "virtual:%s" % origin, strength, origin, -1, payload)


func pulse_intent(intent: StringName, origin: StringName = &"virtual", payload: Dictionary = {}) -> void:
	submit_intent(intent, 1.0, origin, payload)
	submit_intent(intent, 0.0, origin, payload)


func set_profile(new_profile: Profile) -> void:
	reset()
	profile = new_profile


func clear_native_sources() -> void:
	# 禁用原生适配器时只释放原生来源，不影响 AI/触屏等虚拟来源的持续意图。
	for intent in _sources.keys():
		var sources: Dictionary = _sources[intent]
		for source in sources.keys():
			if String(source).begins_with("native:"):
				_set_source(StringName(intent), source, 0.0, &"reset", -1, {})


func reset() -> void:
	_sources.clear()
	# 先统一清零，再发松开事件，消费者在回调内查询轴也应是零。
	var held := _strengths.keys()
	_strengths.clear()
	for intent in held:
		_emit_intent(StringName(intent), 0.0, &"reset", -1, {})


#endregion

#region 聚合来源与语义事件生成
func _set_source(intent: StringName, source: String, value: float, origin: StringName, device: int, payload: Dictionary) -> void:
	if intent.is_empty():
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
	if strength > 0.0:
		_strengths[intent] = strength
	else:
		_strengths.erase(intent)
	# 强度变化也通知消费者；不能将摇杆强度调整重复解释为跳跃/攻击按下。
	var data := payload.duplicate(true)
	data["just_pressed"] = previous <= 0.0 and strength > 0.0
	_emit_intent(intent, strength, origin, device, data)


func _emit_intent(intent: StringName, strength: float, origin: StringName, device: int, payload: Dictionary) -> void:
	var event := Intent.new()
	event.action = intent
	event.strength = strength
	event.pressed = strength > 0.0
	event.origin = origin
	event.device = device
	event.payload = payload
	intent_emitted.emit(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		reset()


func _exit_tree() -> void:
	reset()
#endregion
