extends Control
class_name BattleOperationMenu
#region 菜单控制权与界面
signal menu_changed(open: bool)
const LABELS := {&"move_left": "左移", &"move_right": "右移", &"move_up": "上方向", &"move_down": "下方向", &"run": "奔跑", &"jump": "跳跃", &"attack": "普攻", &"skill_1": "技能槽 1", &"skill_2": "技能槽 2", &"skill_3": "技能槽 3", &"skill_4": "技能槽 4", &"skill_5": "技能槽 5", &"magic_weapon": "法宝", &"wushuang": "无双", &"wing_skill": "翅膀技能", &"ultimate": "奥义", &"item_1": "道具 1", &"item_2": "道具 2", &"pet_toggle": "宠物", &"mount_toggle": "坐骑"}
var controller: CoreOperationController
var _bindings: CoreOperationBindings
var _status: Label
var _rows: VBoxContainer
var _buttons: Dictionary = {}
var _reason: StringName
var _scene_ui: bool = false
#endregion
#region 创建与绑定
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_reason = StringName("operation_menu/%d" % get_instance_id())
	_bindings = CoreSystem.operation_manager.bindings
	_bindings.remap_started.connect(_on_remap_started)
	_bindings.remap_finished.connect(_on_remap_finished)
	_bindings.remap_failed.connect(_on_remap_failed)
	_build_ui()
	hide()

func bind_controller(value: CoreOperationController) -> void:
	if controller != value and is_instance_valid(_bindings):
		_bindings.cancel_remap()
	if is_instance_valid(controller):
		controller.set_control_blocked(_reason, false)
	controller = value
	if controller != null:
		controller.set_control_blocked(_reason, visible)
	_refresh_rows()

func set_open(open: bool) -> void:
	if open == visible:
		return
	if not open:
		_bindings.cancel_remap()
		CoreSystem.audio_manager.save_preferences()
	visible = open
	if is_instance_valid(controller):
		controller.set_control_blocked(_reason, open)
	if open:
		_status.text = "音乐与音效可分别调节或静音。选择操作后按新按键；Esc 返回游戏。"
		var audio_settings := get_node_or_null(^"Margin/Panel/Column/AudioSettings") as BattleAudioSettings
		if audio_settings != null: audio_settings.refresh()
		_refresh_rows()
		grab_focus()
	menu_changed.emit(open)

func _exit_tree() -> void:
	if is_instance_valid(_bindings):
		_bindings.cancel_remap()
	if is_instance_valid(controller):
		controller.set_control_blocked(_reason, false)
#endregion
#region UI 消费与改键
func _gui_input(_event: InputEvent) -> void:
	if visible:
		accept_event()

func _refresh_rows() -> void:
	if _rows == null:
		return
	if _scene_ui:
		_refresh_scene_rows()
		return
	for child in _rows.get_children():
		child.queue_free()
	_buttons.clear()
	if not is_instance_valid(controller) or controller.profile == null:
		return
	for raw_intent in controller.profile.bindings:
		var intent := StringName(raw_intent)
		var actions := controller.profile.get_actions(intent)
		if actions.is_empty():
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_rows.add_child(row)
		var label := Label.new()
		label.text = LABELS.get(intent, String(intent))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var button := Button.new()
		button.custom_minimum_size.x = 220
		button.text = _bindings.get_binding_text(StringName(actions[0]))
		button.pressed.connect(_start_remap.bind(intent))
		row.add_child(button)
		_buttons[intent] = button

func _start_remap(intent: StringName) -> void:
	if not _bindings.start_remap(controller, intent):
		_status.text = _bindings.last_error

func _on_remap_started(action: StringName) -> void:
	if visible:
		var name := String(action)
		for intent in controller.profile.bindings:
			if controller.profile.get_actions(StringName(intent)).has(action):
				name = LABELS.get(intent, String(intent))
				break
		_status.text = "等待新按键：%s（Esc 取消；冲突按键不会覆盖其他操作）" % name

func _on_remap_failed(message: String) -> void:
	if visible:
		for intent in controller.profile.bindings:
			for action in controller.profile.get_actions(StringName(intent)):
				message = message.replace(String(action), LABELS.get(intent, String(intent)))
		_status.text = message

func _on_remap_finished(_action: StringName, succeeded: bool) -> void:
	if visible:
		_status.text = "已更新并保存按键。松开新按键后关闭菜单，再重新按下使用。" if succeeded else "已取消改键。"
		_refresh_rows()
#endregion
#region 模态界面
func _build_ui() -> void:
	if has_node(^"Margin/Panel/Column/Scroll/Rows"):
		_scene_ui = true
		_status = $Margin/Panel/Column/Status
		_rows = $Margin/Panel/Column/Scroll/Rows
		$Margin/Panel/Column/Buttons/Reset.pressed.connect(func(): _bindings.reset_profile(controller.profile); _refresh_rows())
		$Margin/Panel/Column/Buttons/Close.pressed.connect(func(): set_open(false))
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.05, 0.09, 0.93)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 220)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 38)
	add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192d40")
	style.set_corner_radius_all(12)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "操作设置 · 按键重映射"
	heading.add_theme_font_size_override("font_size", 26)
	column.add_child(heading)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = 48
	_status.add_theme_color_override("font_color", Color("f0d19b"))
	column.add_child(_status)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)
	var row := HBoxContainer.new()
	column.add_child(row)
	var reset := Button.new()
	reset.text = "恢复默认按键"
	reset.pressed.connect(func(): _bindings.reset_profile(controller.profile); _refresh_rows())
	row.add_child(reset)
	var close := Button.new()
	close.text = "返回游戏 [Esc]"
	close.pressed.connect(func(): set_open(false))
	row.add_child(close)

## 预置行只更新文字、可见性与连接，不创建/删除控件。
func _refresh_scene_rows() -> void:
	_buttons.clear()
	for row in _rows.get_children():
		var intent := StringName(row.get_meta(&"intent", &""))
		var actions := controller.profile.get_actions(intent) if is_instance_valid(controller) and controller.profile != null else []
		row.visible = not actions.is_empty()
		if actions.is_empty():
			continue
		var button := row.get_node(^"Binding") as Button
		button.text = _bindings.get_binding_text(StringName(actions[0]))
		var callback := _start_remap.bind(intent)
		if not button.pressed.is_connected(callback):
			button.pressed.connect(callback)
		_buttons[intent] = button
#endregion
