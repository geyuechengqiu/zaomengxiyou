extends Node
class_name CoreOperationBindings
#region 共享 InputMap 与用户配置
const CONFIG_SECTION := "operation_bindings"
signal mapping_changed(action: StringName)
signal remap_started(action: StringName)
signal remap_finished(action: StringName, succeeded: bool)
signal remap_failed(message: String)
var last_error: String = ""
var _defaults: Dictionary = {}
var _capture_controller: WeakRef
var _capture_action: StringName = &""
var _capture_persist: bool = true
var _reserved: Dictionary = {KEY_ESCAPE: true}
#endregion
#region 默认配置与重映射
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func install_profile(profile: CoreOperationProfile) -> bool:
	if profile == null:
		return true
	for key_name in profile.reserved_keys:
		_reserved[OS.find_keycode_from_string(key_name)] = true
	for raw_action in profile.default_keys:
		var action := StringName(raw_action)
		if _defaults.has(action):
			continue
		var events: Array[InputEvent] = []
		for key_name in profile.default_keys[raw_action]:
			var code := OS.find_keycode_from_string(String(key_name))
			if code == KEY_NONE:
				return _fail("无效默认键名：" + str(key_name))
			var event := InputEventKey.new()
			event.device = -1
			event.physical_keycode = code
			events.append(event)
		_defaults[action] = events
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
			_replace(action, events)
		if CoreSystem.config_manager.has_key(CONFIG_SECTION, String(action)):
			var saved: Variant = CoreSystem.config_manager.get_value(CONFIG_SECTION, String(action), [])
			var restored: Array[InputEvent] = []
			var valid := saved is Array
			if valid:
				for descriptor in saved:
					var event := _deserialize(descriptor)
					if event == null:
						valid = false
						break
					restored.append(event)
			if valid:
				_replace(action, restored)
	return true

func set_binding(action: StringName, event: InputEvent, persist: bool = true) -> bool:
	if not _defaults.has(action) or not _valid_event(event):
		return _fail("动作未注册或绑定事件无效")
	var template := _binding_template(event)
	var conflicts := get_conflicts(action, template)
	if not conflicts.is_empty():
		return _fail("按键已绑定：" + ", ".join(conflicts))
	if persist:
		var previous: Variant = CoreSystem.config_manager.get_value(CONFIG_SECTION, String(action), InputMap.action_get_events(action).map(_serialize))
		CoreSystem.config_manager.set_value(CONFIG_SECTION, String(action), [_serialize(template)])
		if not CoreSystem.config_manager.save_config():
			CoreSystem.config_manager.set_value(CONFIG_SECTION, String(action), previous)
			return _fail("按键配置保存失败，原绑定保持不变")
	_replace(action, [template])
	mapping_changed.emit(action)
	last_error = ""
	return true

func get_conflicts(action: StringName, event: InputEvent) -> Array[String]:
	var conflicts: Array[String] = []
	for other in _defaults:
		if other == action:
			continue
		for binding in InputMap.action_get_events(other):
			var same_key := false
			if binding is InputEventKey and event is InputEventKey:
				same_key = (binding.physical_keycode if binding.physical_keycode != 0 else binding.keycode) == (event.physical_keycode if event.physical_keycode != 0 else event.keycode)
			if same_key or binding.is_match(event, true):
				conflicts.append(String(other))
				break
	return conflicts

func reset_profile(profile: CoreOperationProfile, persist: bool = true) -> bool:
	if profile == null:
		return false
	for raw_action in profile.default_keys:
		var action := StringName(raw_action)
		if _defaults.has(action):
			_replace(action, _defaults[action])
			mapping_changed.emit(action)
			if persist:
				CoreSystem.config_manager.set_value(CONFIG_SECTION, String(action), _defaults[action].map(_serialize))
	return CoreSystem.config_manager.save_config() if persist else true

func get_binding_text(action: StringName) -> String:
	if not InputMap.has_action(action):
		return "未绑定"
	var labels: Array[String] = []
	for event in InputMap.action_get_events(action):
		labels.append(event.as_text().replace(" (Physical)", "").replace(" (物理)", "").replace(" - Physical", ""))
	return " / ".join(labels) if not labels.is_empty() else "未绑定"
#endregion
#region 捕获期间转交控制权
func start_remap(controller: CoreOperationController, intent: StringName, persist: bool = true) -> bool:
	if not is_instance_valid(controller) or controller.profile == null:
		return _fail("需要有效控制器与操作配置")
	var actions := controller.profile.get_actions(intent)
	if actions.is_empty() or not _defaults.has(StringName(actions[0])):
		return _fail("该意图没有可重映射的动作")
	cancel_remap()
	_capture_controller = weakref(controller)
	_capture_action = StringName(actions[0])
	_capture_persist = persist
	controller.set_control_blocked(&"remapping", true)
	remap_started.emit(_capture_action)
	return true

func is_remapping() -> bool:
	return not _capture_action.is_empty()

func cancel_remap() -> void:
	if not is_remapping():
		return
	var action := _capture_action
	_finish_capture()
	remap_finished.emit(action, false)

func _input(event: InputEvent) -> void:
	if capture_event(event):
		get_viewport().set_input_as_handled()

func capture_event(event: InputEvent) -> bool:
	if not is_remapping():
		return false
	if _capture_controller.get_ref() == null:
		cancel_remap()
		return true
	if event is InputEventKey and event.pressed and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
		cancel_remap()
		return true
	if event.is_echo() or (not event.is_pressed() and not event is InputEventJoypadMotion):
		return true
	if event is InputEventJoypadMotion and absf(event.axis_value) < 0.6:
		return true
	if not _valid_event(event):
		_fail("此输入不能绑定，请选择未保留的按键、鼠标按钮或手柄输入")
		remap_failed.emit(last_error)
		return true
	var action := _capture_action
	if set_binding(action, event, _capture_persist):
		_finish_capture()
		remap_finished.emit(action, true)
	else:
		remap_failed.emit(last_error)
	return true

func _finish_capture() -> void:
	var controller := _capture_controller.get_ref() as CoreOperationController if _capture_controller != null else null
	_capture_controller = null
	_capture_action = &""
	if controller != null:
		controller.set_control_blocked(&"remapping", false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		cancel_remap()

func _exit_tree() -> void:
	cancel_remap()
#endregion
#region 事件模板、序列化与校验
func _replace(action: StringName, events: Array) -> void:
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)

func _valid_event(event: InputEvent) -> bool:
	if event is InputEventKey:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		return code != 0 and not _reserved.has(code)
	if event is InputEventMouseButton:
		return event.button_index >= MOUSE_BUTTON_LEFT and event.button_index <= MOUSE_BUTTON_XBUTTON2
	if event is InputEventJoypadButton:
		return event.button_index >= 0 and event.button_index < JOY_BUTTON_MAX
	if event is InputEventJoypadMotion:
		return event.axis >= 0 and event.axis < JOY_AXIS_MAX and is_finite(event.axis_value) and absf(event.axis_value) >= 0.6
	return false

func _binding_template(event: InputEvent) -> InputEvent:
	var template := event.duplicate() as InputEvent
	template.device = -1
	if template is InputEventKey:
		template.pressed = false
		template.echo = false
		if template.physical_keycode != 0:
			template.keycode = 0
			template.unicode = 0
	elif template is InputEventJoypadMotion:
		template.axis_value = signf(template.axis_value)
	else:
		template.pressed = false
	return template

func _serialize(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "physical": event.physical_keycode, "key": event.keycode, "shift": event.shift_pressed, "ctrl": event.ctrl_pressed, "alt": event.alt_pressed, "meta": event.meta_pressed}
	if event is InputEventJoypadMotion:
		return {"type": "joy_axis", "axis": event.axis, "value": event.axis_value}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button": event.button_index}
	return {"type": "mouse", "button": (event as InputEventMouseButton).button_index}

func _deserialize(value: Variant) -> InputEvent:
	if not value is Dictionary:
		return null
	var event: InputEvent
	match value.get("type", ""):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = value.get("physical", 0)
			key.keycode = value.get("key", 0)
			key.shift_pressed = value.get("shift", false)
			key.ctrl_pressed = value.get("ctrl", false)
			key.alt_pressed = value.get("alt", false)
			key.meta_pressed = value.get("meta", false)
			event = key
		"joy_button":
			var button := InputEventJoypadButton.new()
			button.button_index = value.get("button", -1)
			event = button
		"joy_axis":
			var axis := InputEventJoypadMotion.new()
			axis.axis = value.get("axis", -1)
			axis.axis_value = value.get("value", 0.0)
			event = axis
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = value.get("button", 0)
			event = mouse
		_:
			return null
	return _binding_template(event) if _valid_event(event) else null

func _fail(message: String) -> bool:
	last_error = message
	return false
#endregion
