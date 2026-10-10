extends Node
class_name BattleLevelInstance2D
#region 预置关卡控制器与独立运行状态
enum State { STOPPED, RUNNING, WON, FAILED }
@export var player_path: NodePath = ^"../Actors/SunWukong"
@export var points_path: NodePath = ^"../Actors/SpawnPoints"
@export var gates_path: NodePath = ^"../Actors/Gates"
@export var camera_path: NodePath = ^"../../Camera2D"
@export var camera_rig_path: NodePath = ^"../CameraRig"
var definition: BattleLevelDefinition
var state: State = State.STOPPED
var elapsed: float = 0.0
var current_region_index: int = 0
var death_count: int = 0
var last_error: String = ""
var regions: Array[BattleRegionInstance] = []
var waves: Dictionary = {}
var plans: Dictionary = {}
var conditions: Dictionary = {}
var _points: Dictionary = {}
var _gates: Dictionary = {}
var _owners: Dictionary = {}
var _bindings: Dictionary = {}
var _plan_waves: Dictionary = {}
var _session: BattleSession
var _player: BattleEntity2D
var _previous_position: Vector2
var _pending_exit: bool = false
var _clock_origin: float = 0.0
var _condition_times: Dictionary = {}

func start(data: BattleLevelDefinition) -> bool:
	if state != State.STOPPED: return _configuration_failure("关卡实例只能启动一次；重新开始前必须stop")
	last_error = data.get_progression_error()
	if not last_error.is_empty() or data.regions.is_empty(): return false
	_session = get_parent() as BattleSession
	_player = get_node_or_null(player_path) as BattleEntity2D
	if _player == null or _player.session != _session: return _configuration_failure("关卡玩家未注册到当前会话")
	var point_root := get_node_or_null(points_path)
	var gate_root := get_node_or_null(gates_path)
	if point_root == null or gate_root == null: return _configuration_failure("地图必须预置SpawnPoints和Gates")
	for child in point_root.get_children():
		if not child is BattleSpawnPoint2D or child.spawn_point_id.is_empty() or _points.has(child.spawn_point_id): return _configuration_failure("出生点节点ID或类型无效")
		_points[child.spawn_point_id] = child
	for child in gate_root.get_children():
		if not child is BattleRegionGate2D or _gates.has(child.region_id): return _configuration_failure("出口节点ID或类型无效")
		_gates[child.region_id] = child
	for region in data.regions:
		if not _gates.has(region.region_id): return _configuration_failure("区域没有预置出口：" + String(region.region_id))
	for plan in data.spawn_plans:
		if not _points.has(plan.spawn_point_id): return _configuration_failure("计划出生点不存在：" + String(plan.spawn_point_id))
		for id in plan.monster_ids:
			if not _session.catalog.has_definition("monsters", id): return _configuration_failure("计划怪物未登记：" + String(id))
	definition = data
	elapsed = 0.0
	_clock_origin = _session.clock.elapsed
	death_count = 0
	current_region_index = 0
	for id in data.condition_ids: conditions[id] = false
	for item in data.regions:
		var instance := BattleRegionInstance.new()
		instance.definition = item
		regions.append(instance)
		_gates[item.region_id].set_locked(true)
	for item in data.waves:
		var instance := BattleWaveInstance.new()
		instance.definition = item
		waves[item.wave_id] = instance
		for id in item.plan_ids: _plan_waves[id] = instance
	for item in data.spawn_plans:
		var instance := BattleSpawnPlanInstance.new()
		instance.definition = item
		plans[item.plan_id] = instance
	_previous_position = _player.global_position
	_player.attributes.vital_depleted.connect(_on_player_depleted)
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	state = State.RUNNING
	var map := _player.get_parent() as BattleMap2D
	if map != null: map.set_final_exit_open(false)
	_refresh_camera(true)
	return true

func _configuration_failure(message: String) -> bool:
	last_error = message
	_points.clear()
	_gates.clear()
	return false

func stop() -> void:
	var map := _player.get_parent() as BattleMap2D if is_instance_valid(_player) else null
	if map != null: map.set_final_exit_open(false)
	state = State.STOPPED
	var rig := get_node_or_null(camera_rig_path) as BattleCameraRig2D
	if rig != null: rig.stop()
	_pending_exit = false
	if is_instance_valid(_player) and _player.attributes.vital_depleted.is_connected(_on_player_depleted): _player.attributes.vital_depleted.disconnect(_on_player_depleted)
	if CoreSystem.event_bus.event_pushed.is_connected(_on_event): CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	for id in _bindings.keys(): _disconnect_target(id)
	regions.clear()
	waves.clear()
	plans.clear()
	conditions.clear()
	_condition_times.clear()
	_owners.clear()
	_plan_waves.clear()
	_points.clear()
	_gates.clear()
	definition = null
	_player = null

func _exit_tree() -> void:
	stop()
#endregion
#region 进入区域、战斗时钟调度与完成检查
func advance_level(delta: float) -> void:
	if state != State.RUNNING:
		_pending_exit = false
		return
	if delta <= 0.0:
		if _session.clock.paused or get_tree().paused: _pending_exit = false
		return # 抽帧/命中停顿不丢弃已经收到的出口按下意图。
	if not is_instance_valid(_player) or not _player.is_alive():
		_fail("玩家死亡或离场")
		return
	elapsed += delta
	var region := regions[current_region_index]
	var now := _player.global_position
	var forward_step := now.x > _previous_position.x + 0.0001
	if not region.entered and _crosses(region.definition.entry_rect, _previous_position, now):
		region.entered = true
		region.entered_at = elapsed
		_emit(&"battle.region.entered", {"region_id": region.definition.region_id})
	_previous_position = now
	_sync_camera_lock()
	# 所有定时事件使用绝对combat时间，低帧率补发并跨计划按到期时间排序。
	while state == State.RUNNING:
		_refresh_waves()
		_start_plans()
		var earliest: BattleSpawnPlanInstance
		for candidate: BattleSpawnPlanInstance in plans.values():
			if candidate.next_due <= elapsed + 0.0000001 and (earliest == null or candidate.next_due < earliest.next_due): earliest = candidate
		if earliest == null: break
		_spawn_next(earliest)
	if state != State.RUNNING: return
	_refresh_waves()
	for instance in regions:
		if state != State.RUNNING: return
		if instance.entered and not instance.completed and _region_complete(instance):
			instance.completed = true
			_emit(&"battle.region.completed", {"region_id": instance.definition.region_id})
			if state != State.RUNNING: return
		if instance.completed and not instance.exit_open and (instance != regions[-1] or _level_conditions_met()):
			instance.exit_open = true
			_gates[instance.definition.region_id].set_locked(false)
			if instance == regions[-1]:
				var map := _player.get_parent() as BattleMap2D
				if map != null: map.set_final_exit_open(true)
			_emit(&"battle.region.exit_opened", {"region_id": instance.definition.region_id})
	_sync_camera_lock()
	if forward_step and region.exit_open and region.definition.automatic_exit and region.definition.get_automatic_exit_rect().has_point(now): request_exit(_player, true)
	elif _pending_exit: request_exit(_player)
	_pending_exit = false

func _start_plans() -> void:
	for instance: BattleSpawnPlanInstance in plans.values():
		if state != State.RUNNING: return
		if instance.started: continue
		var cfg := instance.definition
		var wave: BattleWaveInstance = _plan_waves[cfg.plan_id]
		if not wave.started or not _conditions_met(cfg.required_conditions): continue
		var due := maxf(wave.started_at, _conditions_time(cfg.required_conditions))
		var ready := true
		for id in cfg.after_created_plan_ids:
			var predecessor: BattleSpawnPlanInstance = plans[id]
			if not predecessor.generation_complete(): ready = false
			due = maxf(due, predecessor.generation_complete_at)
		for id in cfg.after_dead_plan_ids:
			var predecessor: BattleSpawnPlanInstance = plans[id]
			if not predecessor.all_dead(): ready = false
			due = maxf(due, predecessor.all_dead_at)
		if not ready: continue
		instance.started = true
		instance.next_due = due + cfg.delay_seconds + cfg.interval_seconds
		_emit(&"battle.spawn_plan.started", {"plan_id": cfg.plan_id, "due_time": instance.next_due})

func _refresh_waves() -> void:
	for instance: BattleWaveInstance in waves.values():
		if state != State.RUNNING: return
		if not instance.started:
			var region := get_region(instance.definition.region_id)
			if not region.entered or not _conditions_met(instance.definition.required_conditions): continue
			var ready := true
			var start_at := maxf(region.entered_at, _conditions_time(instance.definition.required_conditions))
			for id in instance.definition.after_wave_ids:
				var predecessor: BattleWaveInstance = waves[id]
				if not predecessor.completed: ready = false
				start_at = maxf(start_at, predecessor.completed_at)
			if not ready: continue
			instance.started = true
			instance.started_at = start_at
			_emit(&"battle.wave.started", {"wave_id": instance.definition.wave_id, "region_id": instance.definition.region_id})
			if state != State.RUNNING: return
		if instance.completed: continue
		var complete := true
		var complete_at := instance.started_at
		for id in instance.definition.plan_ids:
			var plan: BattleSpawnPlanInstance = plans[id]
			if plan.definition.participates_in_clear:
				if not plan.all_dead(): complete = false
				complete_at = maxf(complete_at, plan.all_dead_at)
		if complete:
			instance.completed = true
			instance.completed_at = complete_at
			_emit(&"battle.wave.completed", {"wave_id": instance.definition.wave_id, "region_id": instance.definition.region_id})

func _spawn_next(instance: BattleSpawnPlanInstance) -> void:
	var cfg := instance.definition
	var due := instance.next_due
	var point: BattleSpawnPoint2D = _points[cfg.spawn_point_id]
	var actor := _session.spawn_entity_2d("monsters", cfg.monster_ids[instance.created], point.sample_position(_session.random), &"", true)
	if state != State.RUNNING: return
	if actor == null:
		_fail("出生失败：" + _session.last_error)
		return
	instance.created += 1
	instance.targets[actor.entity_id] = true
	_owners[actor.entity_id] = instance
	actor.animation.set_facing(cfg.facing)
	actor.set_meta(&"spawn_plan_id", cfg.plan_id)
	actor.set_meta(&"level_region_id", (_plan_waves[cfg.plan_id] as BattleWaveInstance).definition.region_id)
	var callback := _on_target_depleted.bind(actor.entity_id)
	actor.attributes.vital_depleted.connect(callback)
	var exit_callback := _on_target_exiting.bind(actor.entity_id)
	actor.tree_exiting.connect(exit_callback)
	_bindings[actor.entity_id] = {"target": weakref(actor), "callback": callback, "exit_callback": exit_callback}
	if instance.generation_complete():
		instance.next_due = INF
		instance.generation_complete_at = due
	else: instance.next_due = due + cfg.interval_seconds
	_emit(&"battle.spawn_plan.spawned", {"plan_id": cfg.plan_id, "entity_id": actor.entity_id, "spawn_index": instance.created, "scheduled_time": due})
	if state != State.RUNNING: return
	if instance.generation_complete(): _emit(&"battle.spawn_plan.created_all", {"plan_id": cfg.plan_id, "scheduled_time": due})
	if not actor.is_alive(): _mark_dead(actor.entity_id)

func _region_complete(region: BattleRegionInstance) -> bool:
	if not _conditions_met(region.definition.required_conditions): return false
	for id in region.definition.wave_ids:
		if not (waves[id] as BattleWaveInstance).completed: return false
	return true

func _level_conditions_met() -> bool:
	if not _conditions_met(definition.required_conditions): return false
	for id in definition.required_boss_plan_ids:
		if not (plans[id] as BattleSpawnPlanInstance).all_dead(): return false
	return true

func _conditions_met(ids: Array[StringName]) -> bool:
	for id in ids:
		if not conditions.get(id, false): return false
	return true

func set_condition(id: StringName, value: bool = true) -> bool:
	if state != State.RUNNING or not conditions.has(id): return false
	if conditions[id] == value: return true
	conditions[id] = value
	_condition_times[id] = maxf(elapsed, _session.clock.elapsed - _clock_origin)
	_emit(&"battle.level.condition_changed", {"condition_id": id, "value": value})
	return true

func _conditions_time(ids: Array[StringName]) -> float:
	var result := 0.0
	for id in ids: result = maxf(result, _condition_times.get(id, 0.0))
	return result

func get_region(id: StringName) -> BattleRegionInstance:
	for region in regions:
		if region.definition.region_id == id: return region
	return null

func request_exit(actor: BattleEntity2D, automatic: bool = false) -> bool:
	if state != State.RUNNING or actor != _player or _session.is_simulation_blocked() or not actor.is_alive(): return false
	var region := regions[current_region_index]
	var exit_rect := region.definition.exit_rect
	if automatic and region.definition.automatic_exit and current_region_index < regions.size()-1: exit_rect = region.definition.get_automatic_exit_rect()
	if region.exited or not region.exit_open or not exit_rect.has_point(actor.global_position): return false
	if current_region_index == regions.size() - 1:
		var stage := _session.presentation.get_node_or_null(^"StageFeedback") as BattleStageFeedback if _session.presentation != null else null
		if stage != null and stage.is_execution_playing(): return false
		for item in regions:
			if not item.completed: return false
		if not _level_conditions_met(): return false
		region.exited = true
		state = State.WON
		_emit(&"battle.region.exited", {"region_id": region.definition.region_id})
		if state != State.WON: return true
		_emit(&"battle.level.victory", {"level_id": definition.definition_id, "death_count": death_count})
	else:
		region.exited = true
		current_region_index += 1
		_refresh_camera()
		_emit(&"battle.region.exited", {"region_id": region.definition.region_id, "next_region_id": regions[current_region_index].definition.region_id})
	return true

func _refresh_camera(initial: bool = false) -> void:
	var rig := get_node_or_null(camera_rig_path) as BattleCameraRig2D
	if rig != null:
		rig.set_region_bounds(regions[current_region_index].definition.bounds,initial)
		_sync_camera_lock()
		return
	var camera := get_node_or_null(camera_path) as Camera2D
	if camera != null:
		camera.limit_left = floori(regions[0].definition.bounds.position.x)
		camera.limit_right = ceili(regions[current_region_index].definition.bounds.end.x)
		camera.limit_top = floori(regions[current_region_index].definition.bounds.position.y)
		camera.limit_bottom = ceili(regions[current_region_index].definition.bounds.end.y)

func _sync_camera_lock() -> void:
	var rig := get_node_or_null(camera_rig_path) as BattleCameraRig2D
	if rig == null or regions.is_empty(): return
	var region := regions[current_region_index]
	# 零活怪可能仍有延迟出生或完成条件，必须沿用区域完整通关判定。
	rig.set_combat_locked(region.entered and not region.completed)

func _crosses(rect: Rect2, from: Vector2, to: Vector2) -> bool:
	if rect.has_point(from) or rect.has_point(to): return true
	# 线段/AABB的slab测试，避免窄触发区在低帧率被跨过。
	var t_min := 0.0
	var t_max := 1.0
	for axis in range(2):
		var change: float = to[axis] - from[axis]
		if is_zero_approx(change):
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]: return false
		else:
			var first: float = (rect.position[axis] - from[axis]) / change
			var last: float = (rect.end[axis] - from[axis]) / change
			t_min = maxf(t_min, minf(first, last))
			t_max = minf(t_max, maxf(first, last))
			if t_min > t_max: return false
	return true
#endregion
#region 唯一死亡统计、Core触发与取消
func _on_target_depleted(id: StringName, target_id: StringName) -> void:
	if id == &"health": _mark_dead(target_id)

func _mark_dead(id: StringName) -> void:
	if state != State.RUNNING or not _owners.has(id): return
	var plan: BattleSpawnPlanInstance = _owners[id]
	if plan.dead_targets.has(id): return
	plan.dead_targets[id] = true
	death_count += 1
	_disconnect_target(id)
	# Vital信号在实体更新中触发，此时Session.clock已经推进到本tick末尾。
	var now := maxf(elapsed, _session.clock.elapsed - _clock_origin)
	if plan.all_dead() and not plan.all_dead_notified:
		plan.all_dead_notified = true
		plan.all_dead_at = now
		_emit(&"battle.spawn_plan.all_dead", {"plan_id": plan.definition.plan_id})
		if state != State.RUNNING: return
	_emit(&"battle.level.target_died", {"entity_id": id, "plan_id": plan.definition.plan_id, "death_count": death_count})

func _disconnect_target(id: StringName) -> void:
	if not _bindings.has(id): return
	var binding: Dictionary = _bindings[id]
	var actor := binding.target.get_ref() as BattleEntity2D
	if is_instance_valid(actor) and actor.attributes.vital_depleted.is_connected(binding.callback): actor.attributes.vital_depleted.disconnect(binding.callback)
	if is_instance_valid(actor) and actor.tree_exiting.is_connected(binding.exit_callback): actor.tree_exiting.disconnect(binding.exit_callback)
	_bindings.erase(id)

func _on_target_exiting(id: StringName) -> void:
	if state == State.RUNNING and _required_target_alive(id): _fail("参与目标存活时被释放，不能算作死亡")
	_disconnect_target(id)

func _required_target_alive(id: StringName) -> bool:
	if not _owners.has(id): return false
	var plan: BattleSpawnPlanInstance = _owners[id]
	return plan.definition.participates_in_clear and not plan.dead_targets.has(id)

func _on_player_depleted(id: StringName) -> void:
	if id == &"health" and state == State.RUNNING: _fail("玩家死亡")

func _on_event(id: String, payload: Array) -> void:
	if state != State.RUNNING or payload.size() != 1 or not payload[0] is Dictionary: return
	var data: Dictionary = payload[0]
	if data.get("battle_id") != _session.battle_id: return
	if id == "battle.entity.killed": _mark_dead(data.target_entity_id)
	elif id == "battle.entity_despawned":
		var target_id: StringName = data.target_entity_id
		if target_id == _player.entity_id or _required_target_alive(target_id): _fail("参与目标存活时离场，不能算作死亡")
		_disconnect_target(target_id)
	elif id == "battle.operation_intent" and data.source_entity_id == _player.entity_id and data.get("intent") == &"move_up" and data.get("phase") == "pressed" and not data.get("operation_payload", {}).get("cancelled", false):
		if not _session.is_simulation_blocked(): _pending_exit = true

func _fail(message: String) -> void:
	if state != State.RUNNING: return
	last_error = message
	state = State.FAILED
	_pending_exit = false
	_emit(&"battle.level.failed", {"level_id": definition.definition_id, "reason": message})

func _emit(id: StringName, data: Dictionary) -> void:
	_session.publish_event(id, null, null, data)
#endregion
