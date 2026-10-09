extends Node2D
#region 预置第一关地图、出口、出生点和关卡组件
@export var enable_player_controls: bool = true
@onready var session: BattleSession = $BattleSession
@onready var player: BattleEntity2D = $BattleSession/Actors/SunWukong
@onready var flow: BattleLevelInstance2D = $BattleSession/LevelInstance
@onready var menu: BattleOperationMenu = $HUD/OperationMenu
@onready var camera: Camera2D = $Camera2D
@onready var info: Label = $HUD/Panel/Column/Info
@onready var message: Label = $HUD/Panel/Column/Message

func _ready() -> void:
	player.operations.enabled = enable_player_controls
	menu.bind_controller(player.operations.controller)
	menu.menu_changed.connect(func(open: bool): session.set_paused(open))
	assert(session.register_scene_level(&"碧玉径", $BattleSession/Actors), session.last_error)
	$HUD/Restart.pressed.connect(func(): get_tree().reload_current_scene())
	CoreSystem.event_bus.event_pushed.connect(_on_event)

func _process(_delta: float) -> void:
	if not is_instance_valid(player) or flow.regions.is_empty(): return
	var region := flow.regions[flow.current_region_index]
	var snapshot := player.attributes.get_snapshot()
	info.text = "孙悟空 · 等级%d · 生命%d/%d · 魔法%d/%d · 碧玉径 %d/%d" % [snapshot.level,snapshot.hp,snapshot.hpMax,snapshot.mp,snapshot.mpMax,flow.current_region_index+1,flow.regions.size()]
	if flow.state == BattleLevelInstance2D.State.WON: message.text = "碧玉径通关！"
	elif flow.state == BattleLevelInstance2D.State.FAILED: message.text = "悟空倒下了，点击重开。" if not player.is_alive() else "关卡已结束，点击重开。"
	elif region.exit_open: message.text = "出口已开启：向右进入下一区域。" if flow.current_region_index < 4 else "Boss已击败，站到出口标记处按W / ↑确认通关。"
	else: message.text = "击败区域内的敌人，继续向右前进。"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		menu.set_open(not menu.visible)
		get_viewport().set_input_as_handled()

func _on_event(id: String, payload: Array) -> void:
	if payload.size() != 1 or payload[0].get("battle_id") != session.battle_id: return
	if id in ["battle.level.victory","battle.level.failed"]:
		player.operations.set_control_blocked(&"level_finished", true)

func _exit_tree() -> void:
	if CoreSystem.event_bus.event_pushed.is_connected(_on_event): CoreSystem.event_bus.event_pushed.disconnect(_on_event)
#endregion
