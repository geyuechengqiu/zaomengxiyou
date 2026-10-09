extends Node
class_name BattleStageFeedback
#region 全场共享斩败，不挂载到悟空；独立UI时钟和一次性死亡触发
@export var silhouette_material: ShaderMaterial
@onready var execution: OriginalUIAnimation2D = $HUD/Execution
var session: BattleSession
var _completed_bosses: Dictionary = {}
var _visuals: Dictionary = {}
var _actors: Dictionary = {}
var _slow_age: float = 0.0
var _slow_index: int = 0
var _slow_wait: int = 0
const SLOW_FRAMES: Array[int] = [1,2,3,3,4,4,5,5,4,4,3,2,1,1,0,0,0]

func _ready() -> void:
	session = get_parent().get_parent() as BattleSession
	execution.completed.connect(_finish_execution)
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	get_viewport().size_changed.connect(_center_execution)
	_center_execution()

func _center_execution() -> void:
	execution.position = get_viewport().get_visible_rect().size / 2

func is_execution_playing() -> bool:
	return execution.active

func _on_event(id: String, payload: Array) -> void:
	if id != "battle.entity_died" or payload.size() != 1 or not payload[0] is Dictionary or payload[0].get("battle_id") != session.battle_id: return
	var actor := session.get_entity(payload[0].source_entity_id) as BattleEntity2D
	if actor == null or not actor.ai_controller is BattleBossController2D or _completed_bosses.has(actor.entity_id): return
	_completed_bosses[actor.entity_id] = true
	start_execution()

func start_execution() -> void:
	if execution.active: return
	_slow_age = 0
	_slow_index = 0
	_slow_wait = 0
	var map := session.get_node_or_null("Actors/Visuals") as Node2D
	if map != null:
		_visuals[map] = map.modulate
		map.modulate = Color.BLACK
	for actor in session.get_entities():
		if not actor is BattleEntity2D: continue
		if actor.operations != null: actor.operations.set_control_blocked(&"boss_execution", true)
		for child in _canvas_descendants(actor.animation):
			_actors[child] = [child.material, child.use_parent_material]
			if child is SpineSprite:
				# 原生Spine绘制使用四类混合材质，不消费CanvasItem.material。
				for property in ["normal_material", "additive_material", "multiply_material", "screen_material"]:
					_actors[child].append(child.get(property))
					child.set(property, silhouette_material)
			child.use_parent_material = false
			child.material = silhouette_material
	execution.play_effect()
	session.publish_event(&"battle.boss.execution_started")

func _canvas_descendants(root: Node) -> Array[CanvasItem]:
	var result: Array[CanvasItem] = []
	if root is CanvasItem: result.append(root)
	for child in root.get_children(): result.append_array(_canvas_descendants(child))
	return result

func filter_combat_delta(delta: float) -> float:
	if not execution.active or _slow_index >= SLOW_FRAMES.size(): return delta
	# SimulateServerFrame.Slow：每原素材帧等待N+1次，只推进一个战斗帧。
	_slow_age += delta
	var result := 0.0
	while _slow_age + 0.0000001 >= 1.0 / 30.0:
		_slow_age -= 1.0 / 30.0
		if _slow_index >= SLOW_FRAMES.size():
			result += 1.0 / 30.0
			continue
		_slow_wait += 1
		if _slow_wait > SLOW_FRAMES[_slow_index]:
			_slow_wait = 0
			_slow_index += 1
			result += 1.0 / 30.0
	return result

func advance_ui(delta: float) -> void:
	execution.advance_effect(delta)

func _finish_execution() -> void:
	_restore_visuals()
	for actor in session.get_entities():
		if actor is BattleEntity2D and actor.operations != null: actor.operations.set_control_blocked(&"boss_execution", false)
	session.publish_event(&"battle.boss.execution_finished")

func _restore_visuals() -> void:
	for node in _visuals:
		if is_instance_valid(node): node.modulate = _visuals[node]
	for node in _actors:
		if is_instance_valid(node):
			node.material = _actors[node][0]
			node.use_parent_material = _actors[node][1]
			if node is SpineSprite:
				var index := 2
				for property in ["normal_material", "additive_material", "multiply_material", "screen_material"]:
					node.set(property, _actors[node][index])
					index += 1
	_visuals.clear()
	_actors.clear()

func clear_feedback() -> void:
	execution.stop_effect()
	_restore_visuals()
	_completed_bosses.clear()
	for actor in session.get_entities():
		if actor is BattleEntity2D and actor.operations != null: actor.operations.set_control_blocked(&"boss_execution", false)

func _exit_tree() -> void:
	_restore_visuals()
	if CoreSystem.event_bus.event_pushed.is_connected(_on_event): CoreSystem.event_bus.event_pushed.disconnect(_on_event)
#endregion
