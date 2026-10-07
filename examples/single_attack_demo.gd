extends Node2D
#region 场景与战斗实例
const MANIFEST := "res://data/battle2d/single_attack/manifest.json"
@export var enable_player_controls: bool = true
var session: BattleSession
var player: BattleEntity2D
var dummies: Array[BattleEntity2D] = []
var operations: BattlePlayerOperations
var menu: BattleOperationMenu
var _previous_pause: bool = false
var total_hits: int = 0
@onready var info: Label = $HUD/Panel/Column/Info
@onready var message: Label = $HUD/Panel/Column/Message

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	session = BattleSystem.create_session(self, MANIFEST, 6001)
	assert(session != null)
	$HUD/Panel/Column/Buttons/Attack.pressed.connect(func(): player.request_attack())
	$HUD/Panel/Column/Buttons/Flip.pressed.connect(flip_player)
	$HUD/Panel/Column/Buttons/Near.pressed.connect(place_near)
	$HUD/Panel/Column/Buttons/Far.pressed.connect(place_far)
	$HUD/Panel/Column/Buttons/Power.pressed.connect(toggle_power)
	$HUD/Panel/Column/Buttons/Reset.pressed.connect(respawn)
	$HUD/Panel/Column/Buttons/Pause.pressed.connect(func(): session.set_paused(not session.clock.paused))
	if enable_player_controls:
		menu = BattleOperationMenu.new()
		$MenuLayer.add_child(menu)
		menu.menu_changed.connect(_on_menu_changed)
	respawn()
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	var console := get_node_or_null("/root/Panku")
	if console != null:
		console.connect("interactive_shell_visibility_changed", _on_console_visibility)

func _exit_tree() -> void:
	if CoreSystem.event_bus.event_pushed.is_connected(_on_event):
		CoreSystem.event_bus.event_pushed.disconnect(_on_event)

func respawn() -> void:
	session.clear_battle()
	session.set_paused(false)
	session.clock.hit_stop_remaining = 0.0
	player = session.spawn_entity_2d("characters", &"孙悟空", Vector2(400, 650))
	dummies.clear()
	for x in [110, 690]:
		dummies.append(session.spawn_entity_2d("monsters", &"木桩", Vector2(x, 650)))
	if enable_player_controls:
		operations = BattlePlayerOperations.new()
		operations.name = "PlayerOperations"
		operations.operation_profile = load("res://data/controls/player_operations.tres") as CoreOperationProfile
		player.operations = operations
		player.add_child(operations)
		menu.bind_controller(operations.controller)
	total_hits = 0
	message.text = "按 J 播放一次普攻。木桩显示生命条、受击闪色、伤害数字及死亡反馈。"

func place_near() -> void:
	dummies[0].position.x = player.position.x - 290.0
	dummies[1].position.x = player.position.x + 290.0

func place_far() -> void:
	dummies[0].position.x = 1050.0
	dummies[1].position.x = 1180.0

func flip_player() -> void:
	if player.action_state.get_permission(&"turn", player.action_profile):
		player.animation.set_facing(-player.animation.get_facing())

func toggle_power() -> void:
	player.attributes.set_base_value(&"atk", 200.0 if player.attributes.get_value(&"atk") < 200.0 else 26.0)

func _on_event(id: String, payload: Array) -> void:
	if not is_instance_valid(player):
		return
	if payload.size() != 1 or payload[0].get("battle_id") != session.battle_id or payload[0].get("source_entity_id") != player.entity_id:
		return
	var data: Dictionary = payload[0]
	match id:
		"battle.attack.started":
			message.text = "起手：进入 Core 攻击状态，等待素材第4帧的命中窗口。"
		"battle.attack.window_opened":
			message.text = "命中窗口开启：持续2个素材帧；重叠多次仍对每个目标只结算一次。"
		"battle.attack.hit":
			total_hits += 1
			var target: BattleEntity2D = session.get_entity(data.target_entity_id)
			message.text = "命中：实际扣血 %.0f / 计算伤害 %.0f%s" % [data.damage, data.calculated_damage, " · 木桩已击杀" if not target.is_alive() else ""]
		"battle.attack.finished":
			if data.reason == &"completed" and data.hit_count == 0:
				message.text = "打空：窗口内没有目标，生命不变；动作结束后恢复待机。"

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var instance := player.attack_instance
	info.text = "状态 %s · 动作 %s · 攻击 %.0f · 朝向 %s · 本场命中 %d\n左木桩 %.0f / 70 · 右木桩 %.0f / 70 · 时间 %.2fs%s · 当前攻击 %s" % [player.action_state.get_name(), player.animation.get_current_action(), player.attributes.get_value(&"atk"), "右" if player.animation.get_facing() > 0 else "左", total_hits, dummies[0].attributes.get_vital_value(&"health"), dummies[1].attributes.get_vital_value(&"health"), session.clock.elapsed, "（暂停）" if session.clock.paused else "", instance.attack_id if instance != null else "未施放"]

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE and menu != null:
		menu.set_open(not menu.visible)
		get_viewport().set_input_as_handled()

func _on_menu_changed(open: bool) -> void:
	if open:
		_previous_pause = session.clock.paused
		session.set_paused(true)
	else:
		session.set_paused(_previous_pause)

func _on_console_visibility(open: bool) -> void:
	if is_instance_valid(operations):
		operations.set_control_blocked(&"console", open)

func _draw() -> void:
	draw_rect(Rect2(-200, -200, 2800, 1400), Color("101e2e"))
	for index in range(7):
		var x := index * 240.0 - 80.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, 650), Vector2(x + 150, 320), Vector2(x + 330, 650)]), Color("192e40"))
	draw_rect(Rect2(-200, 650, 2800, 150), Color("2b4851"))
	draw_rect(Rect2(-200, 650, 2800, 5), Color("5dc3a8"))
	draw_string(ThemeDB.fallback_font, Vector2(28, 740), "A / D 移动 · K 跳跃 · J 单段普攻 · Esc 菜单 / 改键 · 黄色区域读取技能数据，蓝色受击框可在编辑器调整", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("bdd0dd"))
#endregion
