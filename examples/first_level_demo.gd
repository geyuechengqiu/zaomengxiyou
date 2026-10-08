extends Node2D
#region 预置主线小怪验收场景
@export var enable_player_controls: bool = true
@onready var session: BattleSession = $BattleSession
@onready var player: BattleEntity2D = $BattleSession/Actors/SunWukong
@onready var menu: BattleOperationMenu = $HUD/OperationMenu
@onready var camera: Camera2D = $Camera2D
@onready var info: Label = $HUD/Panel/Column/Info
var monsters: Array[BattleEntity2D] = []

func _ready() -> void:
	for child in $BattleSession/Actors.get_children():
		if child is BattleEntity2D and child != player:
			monsters.append(child)
	player.operations.enabled = enable_player_controls
	menu.bind_controller(player.operations.controller)
	menu.menu_changed.connect(func(open: bool): session.set_paused(open))
	assert(session.register_scene_level(&"碧玉径", $BattleSession/Actors), session.last_error)
	$HUD/Panel/Column/Buttons/Restart.pressed.connect(func(): get_tree().reload_current_scene())
	$HUD/Panel/Column/Buttons/Stun.pressed.connect(_stun_nearby)
	$HUD/Panel/Column/Buttons/Slow.pressed.connect(_slow_nearby)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	camera.position.x = clampf(player.global_position.x, 940.0, 10004.0)
	var alive := 0
	var active := 0
	for monster in monsters:
		if is_instance_valid(monster) and monster.is_alive():
			alive += 1
			if monster.ai_controller.state in [&"CHASE", &"CASTING", &"COOLDOWN", &"RETREAT", &"FLEE"]:
				active += 1
	var snapshot := player.attributes.get_snapshot()
	info.text = "悟空 生命 %d/%d · 攻击%d · 存活小怪%d/32 · 交战%d%s" % [snapshot.hp, snapshot.hpMax, snapshot.atk, alive, active, " · 已阵亡，点击重开" if not player.is_alive() else (" · 小怪已清除" if alive == 0 else "")]

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		menu.set_open(not menu.visible)
		get_viewport().set_input_as_handled()

func _stun_nearby() -> void:
	for monster in monsters:
		if is_instance_valid(player) and is_instance_valid(monster) and monster.is_alive() and absf(monster.global_position.x - player.global_position.x) < 800.0:
			monster.apply_status_definition(&"stun", player)

func _slow_nearby() -> void:
	for monster in monsters:
		if is_instance_valid(player) and is_instance_valid(monster) and monster.is_alive() and absf(monster.global_position.x - player.global_position.x) < 800.0:
			monster.apply_status_definition(&"slow", player)
#endregion
