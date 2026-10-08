extends Node2D
class_name BattleWushuangEffect2D
#region 原版普通无双：红色辉光与固定残影池
@export var status_id: StringName = &"normal_wushuang_visual"
@export var source_path: NodePath = ^"../SpineVisual"
@export var glow_color: Color = Color("ff3000")
@export_range(0.01, 2.0) var spawn_interval: float = 0.2
@export_range(0.01, 3.0) var ghost_lifetime: float = 1.0
@export var source_fps: float = 30.0
@export var glow_base_width: float = 10.0
@export var glow_maximum_step: int = 30
var active: bool = false
var elapsed: float = 0.0
var spawn_count: int = 0
var _spawn_time: float = 0.0
var _frame_time: float = 0.0
var _glow_step: int = 0
var _glow_direction: int = 1
var _cursor: int = 0
var _actor: BattleEntity2D
var _source: SpineSprite
var _skin_names: Array[StringName] = []
var _unit_scale: float = 2.0
var _previous_transform := Transform2D.IDENTITY
var _ages := PackedFloat64Array()
var _ghosts: Array[Sprite2D] = []
var _mirrors: Array[BattleSpinePoseMirror2D] = []
var _viewports: Array[SubViewport] = []
@onready var halo: Sprite2D = $LiveHalo
@onready var live_mirror: BattleSpinePoseMirror2D = $LiveCapture/Body
@onready var live_viewport: SubViewport = $LiveCapture
#endregion
#region 绑定已有节点与GAS状态；不创建表现组件
func _ready() -> void:
	_actor = get_parent().get_parent() as BattleEntity2D
	_source = get_node(source_path) as SpineSprite
	_skin_names = get_parent().get_skin_names()
	get_parent().appearance_changed.connect(_on_appearance_changed)
	_unit_scale = (get_parent() as CharacterAnimationAdapter).profile.display_scale
	halo.texture = live_viewport.get_texture()
	halo.material = halo.material.duplicate()
	halo.material.set_shader_parameter("glow_color", glow_color)
	halo.scale = Vector2.ONE * _unit_scale
	for child in $GhostPool.get_children():
		var ghost := child as Sprite2D
		var viewport := ghost.get_node(^"Capture") as SubViewport
		ghost.texture = viewport.get_texture()
		ghost.material = ghost.material.duplicate()
		ghost.material.set_shader_parameter("glow_color", glow_color)
		ghost.top_level = true
		_ghosts.append(ghost)
		_mirrors.append(viewport.get_node(^"Body"))
		_viewports.append(viewport)
		_ages.append(-1.0)
	assert(_ghosts.size() >= ceili(ghost_lifetime / spawn_interval) + 1, "残影固定池需要覆盖寿命与采样间隔")
	# 独立打开动画适配层进行预览/验收时无需战斗实体。
	if _actor == null: return
	_actor.statuses.status_applied.connect(_on_status_applied)
	_actor.statuses.status_removed.connect(_on_status_removed)
	_actor.attributes.vital_depleted.connect(_on_vital_depleted)
	_previous_transform = get_parent().global_transform
	_sync_status()

func _on_status_applied(id: StringName, _instance: GameplayStatusInstance) -> void:
	if id == status_id: _sync_status()

func _on_appearance_changed(skins: Array[StringName]) -> void:
	_skin_names = skins.duplicate()

func _on_status_removed(id: StringName) -> void:
	if id == status_id: _sync_status()

func _sync_status() -> void:
	var next := _actor.is_alive() and _actor.statuses.has_status(status_id)
	if next and not active:
		elapsed = 0.0
		_spawn_time = 0.0
		_frame_time = 0.0
		_glow_step = 0
		_glow_direction = 1
		_previous_transform = get_parent().global_transform
	active = next
	halo.visible = active
	if active:
		_set_glow_width()
		live_mirror.capture(_source, Vector2(160, 240), _unit_scale, _skin_names)
		live_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		live_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _on_vital_depleted(id: StringName) -> void:
	if id == &"health": clear_effect()

func _exit_tree() -> void:
	if is_instance_valid(_actor):
		if _actor.statuses.status_applied.is_connected(_on_status_applied): _actor.statuses.status_applied.disconnect(_on_status_applied)
		if _actor.statuses.status_removed.is_connected(_on_status_removed): _actor.statuses.status_removed.disconnect(_on_status_removed)
		if _actor.attributes.vital_depleted.is_connected(_on_vital_depleted): _actor.attributes.vital_depleted.disconnect(_on_vital_depleted)
#endregion
#region 只消费战斗时间：辉光脉动、姿态快照与线性消散
func advance_effect(delta: float) -> void:
	if not is_instance_valid(_actor): return
	if not _actor.is_alive():
		clear_effect()
		return
	if delta <= 0.0: return
	for index in range(_ages.size()):
		if _ages[index] < 0.0: continue
		_ages[index] += delta
		if _ages[index] + 0.0000001 >= ghost_lifetime:
			_ages[index] = -1.0
			_ghosts[index].visible = false
		else:
			_ghosts[index].modulate.a = 1.0 - _ages[index] / ghost_lifetime
	if not active: return
	elapsed += delta
	_frame_time += delta
	while _frame_time + 0.0000001 >= 1.0 / source_fps:
		_frame_time = maxf(0.0, _frame_time - 1.0 / source_fps)
		_glow_step += _glow_direction
		if _glow_step >= glow_maximum_step: _glow_direction = -1
		elif _glow_step < 0: _glow_direction = 1
	_set_glow_width()
	live_mirror.capture(_source, Vector2(160, 240), _unit_scale, _skin_names)
	live_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_spawn_time += delta
	var now := get_parent().global_transform as Transform2D
	while _spawn_time + 0.0000001 >= spawn_interval:
		_spawn_time = maxf(0.0, _spawn_time - spawn_interval)
		# 大delta中过期的采样不渲染；保留仍存活采样的年龄和插值世界位置。
		if _spawn_time < ghost_lifetime:
			_spawn_ghost(_spawn_time, _previous_transform.interpolate_with(now, clampf(1.0 - _spawn_time / delta, 0.0, 1.0)))
	_previous_transform = now

func _set_glow_width() -> void:
	halo.material.set_shader_parameter("blur_width", glow_base_width + _glow_step)

func _spawn_ghost(age: float, world_pose: Transform2D) -> void:
	var index := _cursor
	_cursor = (_cursor + 1) % _ghosts.size()
	var ghost := _ghosts[index]
	_mirrors[index].capture(_source, Vector2(120, 180), _unit_scale, _skin_names)
	_viewports[index].render_target_update_mode = SubViewport.UPDATE_ONCE
	ghost.global_transform = world_pose.scaled_local(Vector2.ONE * _unit_scale)
	ghost.material.set_shader_parameter("blur_width", glow_base_width + _glow_step)
	ghost.modulate = Color(1, 1, 1, 1.0 - age / ghost_lifetime)
	ghost.visible = true
	# 原版zSort随生成序号递增；复用池时更新绘制顺序，最新残影盖住旧残影。
	$GhostPool.move_child(ghost, $GhostPool.get_child_count() - 1)
	_ages[index] = age
	spawn_count += 1

func clear_effect() -> void:
	active = false
	halo.visible = false
	live_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	for index in range(_ages.size()):
		_ages[index] = -1.0
		_ghosts[index].visible = false
		_viewports[index].render_target_update_mode = SubViewport.UPDATE_DISABLED

func get_active_ghost_count() -> int:
	var count := 0
	for age in _ages:
		if age >= 0.0: count += 1
	return count
#endregion
