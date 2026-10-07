extends Node2D
#region 场景状态
const MANIFEST := "res://data/battle2d/manifest.json"
@export var enable_player_controls: bool = true
const OUTFITS: Array[StringName] = [&"套装/0", &"套装/2", &"套装/7_7", &"套装/_donghuang"]
const WEAPONS: Array[StringName] = [&"武器/weapon0", &"武器/weapon2", &"武器/weapon7_7", &"武器/weapon_donghuang"]
var session: BattleSession
var player: BattleEntity2D
var left_target: BattleEntity2D
var right_target: BattleEntity2D
var camera: Camera2D
var info: Label
var message: Label
var outfit_index: int = -1
var weapon_index: int = -1
var operations: BattlePlayerOperations
var operation_menu: BattleOperationMenu
var last_operation: String = "等待操作意图"
var _help: Label
var _menu_was_paused: bool = false
var _console_logger: Node
var _console_overlay_mode: int = 0
var platforms: Array[Rect2] = [Rect2(-200, 650, 2800, 150), Rect2(850, 520, 230, 28), Rect2(1190, 400, 210, 28), Rect2(1530, 520, 280, 28), Rect2(2150, 400, 45, 250)]
var one_way_platforms: Array[Rect2] = [Rect2(1840, 430, 180, 18)]
var ceilings: Array[Rect2] = [Rect2(640, 290, 110, 22)]
#endregion
#region 初始化
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	## 演示期间将可选 Panku 日志移到控制台内，退出时恢复；不保存用户配置。
	_console_logger = get_node_or_null("/root/Panku/_Modules_/native_logger")
	if _console_logger != null:
		_console_overlay_mode = _console_logger.get("output_overlay_display_mode")
		_console_logger.call("set_overlay_display_mode", 1)
	for rect in platforms + one_way_platforms + ceilings:
		var body := StaticBody2D.new()
		body.position = rect.get_center()
		body.collision_layer = 1
		body.collision_mask = 2
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		collision.shape = shape
		collision.one_way_collision = one_way_platforms.has(rect)
		body.add_child(collision)
		add_child(body)
	session = BattleSystem.create_session(self, MANIFEST, 2001)
	assert(session != null)
	session.set_time_scale(1.0)
	camera = Camera2D.new()
	camera.position = Vector2(640, 400)
	add_child(camera)
	camera.make_current()
	_build_ui()
	if enable_player_controls:
		var menu_layer := CanvasLayer.new()
		menu_layer.layer = 30
		add_child(menu_layer)
		operation_menu = BattleOperationMenu.new()
		menu_layer.add_child(operation_menu)
		operation_menu.menu_changed.connect(_on_menu_changed)
	respawn()
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	var console := get_node_or_null("/root/Panku")
	if console != null:
		console.connect("interactive_shell_visibility_changed", _on_console_visibility)

func _exit_tree() -> void:
	if is_instance_valid(_console_logger):
		_console_logger.call("set_overlay_display_mode", _console_overlay_mode)

func respawn() -> void:
	session.clear_battle()
	session.set_paused(false)
	session.clock.hit_stop_remaining = 0.0
	player = session.spawn_entity_2d("characters", &"孙悟空", Vector2(350, 648))
	left_target = session.spawn_entity_2d("characters", &"孙悟空", Vector2(120, 648), &"enemy")
	right_target = session.spawn_entity_2d("characters", &"孙悟空", Vector2(600, 648), &"enemy")
	left_target.animation.set_facing(1)
	right_target.animation.set_facing(-1)
	left_target.animation.set_skins([&"套装/2", &"武器/weapon2"])
	right_target.animation.set_skins([&"套装/7_7", &"武器/weapon7_7"])
	if enable_player_controls:
		operations = BattlePlayerOperations.new()
		operations.operation_profile = load("res://data/controls/player_operations.tres") as CoreOperationProfile
		operations.name = "PlayerOperations"
		player.operations = operations
		player.add_child(operations)
		operations.operation_observed.connect(_on_operation)
		operation_menu.bind_controller(operations.controller)
	outfit_index = -1
	weapon_index = -1
	message.text = "绿色十字：脚底原点   金色点：武器骨骼挂点   J 攻击时显示原版判定框"
#endregion
#region 输入与界面更新
func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	camera.position.x = clampf(player.position.x + 180, 640, 1760)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and operation_menu != null:
		if CoreSystem.operation_manager.bindings.is_remapping():
			CoreSystem.operation_manager.bindings.cancel_remap()
		else:
			operation_menu.set_open(not operation_menu.visible)
		get_viewport().set_input_as_handled()

func _on_menu_changed(open: bool) -> void:
	if open:
		_menu_was_paused = session.clock.paused
		session.set_paused(true)
	else:
		session.set_paused(_menu_was_paused)

func _on_console_visibility(open: bool) -> void:
	if is_instance_valid(operations):
		operations.set_control_blocked(&"console", open)

func _on_operation(intent: CoreOperationIntent) -> void:
	last_operation = "%s / %s / %.2fs%s" % [intent.action, intent.get_phase_name(), intent.held_seconds, " / 双击" if intent.payload.get("double_tap", false) else ""]

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or player == null:
		return
	match event.physical_keycode:
		KEY_F1: player.receive_damage(10)
		KEY_F2: player.receive_damage(10000)
		KEY_F4: respawn()
		KEY_F8: player.animation.set_facing(-player.animation.get_facing())
		KEY_1: cycle_outfit()
		KEY_2: cycle_weapon()
		KEY_F9: session.set_paused(not session.clock.paused)
		KEY_F10: toggle_slow_motion()
		KEY_F11: session.request_hit_stop(0.2)
		KEY_F3: toggle_registration()

func _process(_delta: float) -> void:
	if player == null:
		return
	var anim := player.animation
	info.text = "战斗状态  %s     动作  %s     进度  %3.0f%% / %.3fs\n生命  %.0f / %.0f     脚底  (%0.1f, %0.1f)     朝向  %s     时钟  %.2fs  ×%.2f%s\n左靶生命  %.0f     右靶生命  %.0f     外观  %s" % [player.action_state.get_name(), anim.get_current_action(), anim.get_playback_progress() * 100, anim.get_action_duration(anim.get_current_action()), player.attributes.get_vital_value(&"health"), player.attributes.get_value(&"hpMax"), player.position.x, player.position.y, "右" if anim.get_facing() > 0 else "左", session.clock.elapsed, session.clock.time_scale, "（暂停）" if session.clock.paused else "", left_target.attributes.get_vital_value(&"health"), right_target.attributes.get_vital_value(&"health"), ", ".join(anim.get_skin_names())]
	if is_instance_valid(operations):
		info.text += "\n操作意图  %s     缓存  %d" % [last_operation, operations.controller.peek_buffered_intents().size()]
		var bindings := CoreSystem.operation_manager.bindings
		_help.text = "移动 %s / %s · 二段跳 %s · 连按 %s 五段普攻 · 法宝 %s · 无双 %s · 双击方向奔跑\nEsc 菜单/改键 · F1 受击 / F2 死亡 / F4 重生 / F8 翻转 · F9 暂停 / F10 慢动作 / F11 停顿 · 1/2 换装" % [bindings.get_binding_text(&"battle_player.left"), bindings.get_binding_text(&"battle_player.right"), bindings.get_binding_text(&"battle_player.jump"), bindings.get_binding_text(&"battle_player.attack"), bindings.get_binding_text(&"battle_player.magic_weapon"), bindings.get_binding_text(&"battle_player.wushuang")]
	info.text += "\n支撑 %s · 跳跃预算 %d / %d · 连击 %d / 5 · 下一段 %s" % ["地面" if player.motion.grounded else "空中", player.motion.jumps_used, player.action_profile.maximum_jumps, player.combo.index + 1, "已预约" if player.combo.queued_next else "未预约"]

func cycle_outfit() -> void:
	outfit_index = (outfit_index + 1) % OUTFITS.size()
	## 套装只替换衣服/头盔；保留当前独立武器。
	player.animation.set_equipment_skin(&"outfit", OUTFITS[outfit_index])

func cycle_weapon() -> void:
	weapon_index = (weapon_index + 1) % WEAPONS.size()
	player.animation.set_equipment_skin(&"weapon", WEAPONS[weapon_index])

func toggle_slow_motion() -> void:
	session.set_time_scale(0.25 if is_equal_approx(session.clock.time_scale, 1.0) else 1.0)

func toggle_registration() -> void:
	for entity in session.get_entities():
		entity.show_registration = not entity.show_registration
		entity.queue_redraw()

func _on_event(event_id: String, payload: Array) -> void:
	if event_id == "battle.operation_result" and payload.size() == 1 and payload[0].get("entity") == player and payload[0].get("result") == "UNAVAILABLE":
		message.text = "已收到 %s 意图；当前角色尚未配置此操作的技能或专属行为。" % payload[0].intent
		return
	if event_id != "battle.attack.hit" or payload.size() != 1 or payload[0].get("battle_id") != session.battle_id:
		return
	message.text = "普攻第 %d 段 / 命中 %d：素材第 %d 帧 = %.3fs，伤害 %.1f" % [payload[0].combo_step, payload[0].hit_index, payload[0].source_frame, payload[0].skill_time, payload[0].damage]
#endregion
#region 横版平台绘制
func _draw() -> void:
	draw_rect(Rect2(-200, -200, 2800, 1400), Color("101e2e"))
	for i in range(9):
		var x := float(i) * 340 - 120
		draw_colored_polygon(PackedVector2Array([Vector2(x, 650), Vector2(x + 200, 260 + (i % 3) * 55), Vector2(x + 440, 650)]), Color("192e40"))
	draw_circle(Vector2(1080, 255), 48, Color("9abdb8"))
	for rect in platforms + ceilings:
		draw_rect(rect, Color("2b4851"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 5)), Color("5dc3a8"))
	for rect in one_way_platforms:
		draw_rect(rect, Color("80623f"))
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), Color("ffd080"))
	for x in range(0, 2400, 100):
		draw_line(Vector2(x, 657), Vector2(x, 667), Color("6a9b98"), 1)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(290, 706), "PLAYER / 孙悟空", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("8ee0c3"))
	draw_string(font, Vector2(58, 734), "LEFT TARGET", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("bdd0dd"))
	draw_string(font, Vector2(552, 734), "RIGHT TARGET", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("bdd0dd"))
	draw_string(font, Vector2(871, 557), "JUMP TEST", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("bdd0dd"))
	draw_string(font, Vector2(1204, 438), "UPPER PLATFORM", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("bdd0dd"))
#endregion
#region 测试操作面板
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	panel.offset_left = 20
	panel.offset_top = 16
	panel.offset_right = -20
	var style := StyleBoxFlat.new()
	style.bg_color = Color("192b3df2")
	style.border_color = Color("3d5b6b")
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var title := Label.new()
	title.text = "孙悟空 · 移动 / 二段跳 / 五段普攻验收"
	title.add_theme_font_size_override("font_size", 25)
	column.add_child(title)
	info = Label.new()
	info.add_theme_font_size_override("font_size", 17)
	column.add_child(info)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	for entry in [["换套装 [1]", cycle_outfit], ["换武器 [2]", cycle_weapon], ["暂停 [F9]", func(): session.set_paused(not session.clock.paused)], ["慢动作 [F10]", toggle_slow_motion], ["停顿 [F11]", func(): session.request_hit_stop(0.2)], ["重置 [F4]", respawn], ["检查标记 [F3]", toggle_registration], ["操作设置 [Esc]", func(): operation_menu.set_open(true) if operation_menu != null else null]]:
		var button := Button.new()
		button.text = entry[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(entry[1])
		row.add_child(button)
	message = Label.new()
	message.add_theme_color_override("font_color", Color("f5d59a"))
	message.add_theme_font_size_override("font_size", 16)
	column.add_child(message)
	_help = Label.new()
	_help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_help.offset_top = -58
	_help.offset_left = 22
	_help.add_theme_font_size_override("font_size", 16)
	layer.add_child(_help)
#endregion
