extends Node2D
class_name BattleDamageNumberLayer2D
#region 有界节点池与活动索引
@export var number_scene: PackedScene
## 缓存上限不限制显示数量；超过上限的空闲节点释放，永不丢弃有效伤害。
@export_range(0, 20000, 1) var max_cached_numbers: int = 6000
@export_range(0, 10000, 1) var prewarm_count: int = 0
var _cached: Array[BattleDamageNumber2D] = []
var _active: Array[BattleDamageNumber2D] = []
var _cached_scene: PackedScene
var _generation: int = 0
var created_count: int = 0
var reused_count: int = 0
var _spawn_serial: int = 0
var _order_dirty: bool = false
#endregion
#region 预热、生成与复用
func _ready() -> void:
	RenderingServer.frame_pre_draw.connect(_refresh_render_order)
	if number_scene != null:
		prewarm(number_scene, prewarm_count)

func prewarm(scene: PackedScene, count: int) -> void:
	_select_scene(scene)
	while _cached.size() < mini(count, max_cached_numbers):
		var row := _create_number(scene)
		add_child(row)
		row.visible = false
		row.finished = true
		_cached.append(row)

func _select_scene(scene: PackedScene) -> void:
	if _cached_scene == scene:
		return
	_clear_cached()
	_cached_scene = scene
	_generation += 1

func _create_number(scene: PackedScene) -> BattleDamageNumber2D:
	var row := scene.instantiate() as BattleDamageNumber2D
	row.recycle_callback = _recycle
	row.pool_generation = _generation
	created_count += 1
	return row

func spawn_number(scene: PackedScene, value: int, style: String, at: Vector2) -> BattleDamageNumber2D:
	_select_scene(scene)
	var row: BattleDamageNumber2D
	if _cached.is_empty():
		row = _create_number(scene)
	else:
		row = _cached.pop_back()
		reused_count += 1
	row.number = value
	row.style = style
	row.position = at
	row.rotation = 0.0
	row.scale = Vector2.ONE
	row.modulate = Color.WHITE
	row.pool_index = _active.size()
	_active.append(row)
	_spawn_serial += 1
	row.spawn_order = _spawn_serial
	var restart := row.has_started
	if row.get_parent() == null:
		add_child(row)
	if restart:
		row._start_fly()
	RenderingServer.canvas_item_set_draw_index(row.get_canvas_item(), row.spawn_order)
	return row
#endregion
#region 活动更新、回收和卸载
func advance_numbers(delta: float) -> void:
	if delta <= 0.0:
		return
	# 倒序支持动画结束时立即swap-remove，不跳过或重复推进其它实例。
	for index in range(_active.size() - 1, -1, -1):
		var row := _active[index]
		if is_instance_valid(row):
			row.advance_number(delta)
		else:
			_remove_active(index)

func _remove_active(index: int) -> void:
	var last := _active.size() - 1
	if index != last:
		_active[index] = _active[last]
		if is_instance_valid(_active[index]):
			_active[index].pool_index = index
	_active.pop_back()

func _recycle(row: BattleDamageNumber2D) -> void:
	_remove_active(row.pool_index)
	row.pool_index = -1
	# 隐藏缓存保持在树内，避免每次命中的退出/进入通知、Canvas重建和ready检查。
	if row.pool_generation == _generation and _cached.size() < max_cached_numbers:
		_cached.append(row)
	else:
		row.queue_free()

func clear_numbers() -> void:
	for index in range(_active.size() - 1, -1, -1):
		var row := _active[index]
		if is_instance_valid(row):
			row.advance_number(BattleDamageNumber2D.DURATION)
		else:
			_remove_active(index)
	_clear_cached()

func get_active_count() -> int:
	return _active.size()

func get_active_numbers() -> Array[BattleDamageNumber2D]:
	var rows := _active.duplicate()
	rows.sort_custom(func(a: BattleDamageNumber2D, b: BattleDamageNumber2D): return a.spawn_order < b.spawn_order)
	return rows

func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		_order_dirty = true

func _refresh_render_order() -> void:
	if not _order_dirty:
		return
	_order_dirty = false
	# Node新增/删除触发的默认顺序刷新完成后，恢复命中时间顺序。
	for row in _active:
		if not is_instance_valid(row):
			continue
		RenderingServer.canvas_item_set_draw_index(row.get_canvas_item(), row.spawn_order)

func get_pool_stats() -> Dictionary:
	return {"active": _active.size(), "cached": _cached.size(), "created": created_count, "reused": reused_count, "limit": max_cached_numbers}

func _clear_cached() -> void:
	for row in _cached:
		row.free()
	_cached.clear()

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(_refresh_render_order):
		RenderingServer.frame_pre_draw.disconnect(_refresh_render_order)
	# 树内缓存由父节点正常释放，未入树的节点需要显式释放。
	for row in _cached:
		if row.get_parent() == null:
			row.free()
	_cached.clear()
	_active.clear()
#endregion
