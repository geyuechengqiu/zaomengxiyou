extends Node2D
#region 预置场景与战斗实例
const MANIFEST := "res://data/battle2d/single_attack/manifest.json"
@export var enable_player_controls: bool = true
@onready var session: BattleSession = $BattleSession
@onready var player: BattleEntity2D = $BattleSession/Actors/SunWukong
@onready var dummies: Array[BattleEntity2D] = [$BattleSession/Actors/LeftDummy, $BattleSession/Actors/RightDummy]
@onready var operations: BattlePlayerOperations = $BattleSession/Actors/SunWukong/PlayerOperations
@onready var menu: BattleOperationMenu = $MenuLayer/OperationMenu
var _previous_pause: bool = false
var total_hits: int = 0
@onready var info: Label = $HUD/Panel/Column/Info
@onready var message: Label = $HUD/Panel/Column/Message

func _ready() -> void:
	operations.enabled = enable_player_controls
	$HUD/Panel/Column/Buttons/Attack.pressed.connect(func(): player.request_attack())
	$HUD/Panel/Column/Buttons/Flip.pressed.connect(flip_player)
	$HUD/Panel/Column/Buttons/Near.pressed.connect(place_near)
	$HUD/Panel/Column/Buttons/Far.pressed.connect(place_far)
	$HUD/Panel/Column/Buttons/Power.pressed.connect(toggle_power)
	$HUD/Panel/Column/Buttons/Reset.pressed.connect(reload_scene)
	$HUD/Panel/Column/Buttons/Pause.pressed.connect(func(): session.set_paused(not session.clock.paused))
	menu.bind_controller(operations.controller)
	menu.menu_changed.connect(_on_menu_changed)
	message.text = "J 单段普攻：打中、打空、击杀；命中时播放原版受击特效。"
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	var console := get_node_or_null("/root/Panku")
	if console != null:
		console.connect("interactive_shell_visibility_changed", _on_console_visibility)

func _exit_tree() -> void:
	if CoreSystem.event_bus.event_pushed.is_connected(_on_event):
		CoreSystem.event_bus.event_pushed.disconnect(_on_event)

func reload_scene() -> void:
	# F6 与重置均加载完整预置场景，不单独生成角色或控件。
	get_tree().reload_current_scene()

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
			message.text = "命中：实际扣血 %.0f / 计算伤害 %.0f%s" % [data.damage, data.calculated_damage, " · 木桩已击杀" if is_instance_valid(target) and not target.is_alive() else ""]
		"battle.attack.finished":
			if data.reason == &"completed" and data.hit_count == 0:
				message.text = "打空：窗口内没有目标，生命不变；动作结束后恢复待机。"

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(dummies[0]) or not is_instance_valid(dummies[1]):
		return
	info.text = "状态 %s · 攻击 %.0f · 朝向 %s · 命中 %d\n左木桩 %.0f / 70 · 右木桩 %.0f / 70 · 时间 %.0fms%s" % [player.action_state.get_name(), player.attributes.get_value(&"atk"), "右" if player.animation.get_facing() > 0 else "左", total_hits, dummies[0].attributes.get_vital_value(&"health"), dummies[1].attributes.get_vital_value(&"health"), session.clock.elapsed * 1000.0, "（暂停）" if session.clock.paused else ""]

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

#endregion
