extends Node3D
class_name BattleSession
#region 战斗运行状态
var battle_id: StringName = &""
var clock := BattleClock.new()
var catalog := BattleCatalog.new()
var random := BattleRandom.new()
var factions := BattleFactions.new()
var current_level_id: StringName = &""
var last_error: String = ""
var _entities: Dictionary = {}
var _entity_serial: int = 0
var _equipment_serial: int = 0
var _event_sequence: int = 0
var _configured: bool = false
var _event_bus: Node
var _level_root: Node
var _advancing: bool = false
#endregion
#region 固定物理生命周期
func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_event_bus = CoreSystem.event_bus
	if not _event_bus.event_pushed.is_connected(_on_core_event):
		_event_bus.event_pushed.connect(_on_core_event)

func _exit_tree() -> void:
	if is_instance_valid(_event_bus) and _event_bus.event_pushed.is_connected(_on_core_event):
		_event_bus.event_pushed.disconnect(_on_core_event)
	_event_bus = null

func _physics_process(delta: float) -> void:
	## Engine.time_scale 不由本插件修改，避免再乘一次全局缩放。
	var unscaled_delta := delta / Engine.time_scale if Engine.time_scale > 0.0 else 0.0
	advance_physics(unscaled_delta)
#endregion
#region 配置与实体
func configure(id: StringName, manifest_path: String, seed_value: int) -> bool:
	if _configured or id.is_empty():
		last_error = "战斗只能配置一次，且 battle_id 不能为空"
		return false
	if not catalog.load_manifest(manifest_path):
		last_error = catalog.last_error
		return false
	battle_id = id
	random.initialize(seed_value)
	factions.set_relation(&"player", &"enemy", BattleFactions.Relation.HOSTILE)
	_configured = true
	return true

func spawn_entity(category: String, id: StringName, at: Vector3 = Vector3.ZERO, faction_override: StringName = &"") -> BattleEntity:
	if not _configured or not ["characters", "monsters"].has(category):
		last_error = "战斗未配置或实体类别无效"
		return null
	var data := catalog.instantiate_definition(category, id) as BattleEntityDefinition
	if data == null:
		last_error = catalog.last_error
		return null
	var node: Node = data.scene.instantiate() if data.scene != null else BattleEntity.new()
	if not node is BattleEntity:
		node.free()
		last_error = "实体场景根节点必须继承 BattleEntity"
		return null
	var entity := node as BattleEntity
	_entity_serial += 1
	var runtime_id := StringName("%s/entity/%d" % [battle_id, _entity_serial])
	entity.position = at
	## 注册和初始化在入树前完成，避免带初始技能的组件被 _ready 再初始化。
	entity.initialize_battle(self, runtime_id, data)
	if not faction_override.is_empty():
		entity.faction_id = faction_override
	_entities[runtime_id] = entity
	entity.tree_exiting.connect(_on_entity_exiting.bind(runtime_id), CONNECT_ONE_SHOT)
	add_child(entity)
	publish_event(&"battle.entity_spawned", null, entity, {"definition_id": id, "category": category})
	return entity

func spawn_entity_2d(category: String, id: StringName, at: Vector2 = Vector2.ZERO, faction_override: StringName = &"") -> BattleEntity2D:
	if not _configured or not ["characters", "monsters"].has(category):
		last_error = "战斗未配置或实体类别无效"
		return null
	var data := catalog.instantiate_definition(category, id) as BattleEntityDefinition
	if data == null:
		last_error = catalog.last_error
		return null
	var node: Node = data.scene.instantiate() if data.scene != null else BattleEntity2D.new()
	if not node is BattleEntity2D:
		node.free()
		last_error = "2D 实体场景根节点必须继承 BattleEntity2D"
		return null
	var entity := node as BattleEntity2D
	_entity_serial += 1
	entity.position = at
	var runtime_id := StringName("%s/entity/%d" % [battle_id, _entity_serial])
	entity.initialize_battle(self, runtime_id, data)
	if not faction_override.is_empty():
		entity.faction_id = faction_override
	_entities[runtime_id] = entity
	entity.tree_exiting.connect(_on_entity_exiting.bind(runtime_id), CONNECT_ONE_SHOT)
	add_child(entity)
	publish_event(&"battle.entity_spawned", null, entity, {"definition_id": id, "category": category})
	return entity

func get_entity(id: StringName) -> Variant:
	return _entities.get(id)

func get_entities() -> Array:
	return _entities.values().duplicate()

func despawn_entity(id: StringName) -> void:
	var entity: Variant = get_entity(id)
	if entity == null:
		return
	entity.cleanup_battle()
	publish_event(&"battle.entity_despawned", null, entity)
	_entities.erase(id)
	entity.queue_free()

func create_equipment(id: StringName) -> BattleEquipmentState:
	var data := catalog.instantiate_definition("equipment", id) as BattleEquipmentDefinition
	if data == null:
		last_error = catalog.last_error
		return null
	_equipment_serial += 1
	var state := BattleEquipmentState.new()
	state.initialize(StringName("%s/equipment/%d" % [battle_id, _equipment_serial]), data)
	return state

func start_level(id: StringName) -> bool:
	if not current_level_id.is_empty():
		last_error = "先清理当前战斗再开始另一个关卡"
		return false
	var data := catalog.instantiate_definition("levels", id) as BattleLevelDefinition
	if data == null:
		last_error = catalog.last_error
		return false
	if data.scene != null:
		_level_root = data.scene.instantiate()
		add_child(_level_root)
	var spawned: Array[StringName] = []
	for spawn in data.spawns:
		var entity := spawn_entity(spawn.category, spawn.entity_definition_id, spawn.position, spawn.faction_override)
		if entity == null:
			for spawned_id in spawned:
				despawn_entity(spawned_id)
			if is_instance_valid(_level_root):
				_level_root.queue_free()
			return false
		spawned.append(entity.entity_id)
	current_level_id = id
	publish_event(&"battle.level_started", null, null, {"level_id": id})
	return true

func clear_battle() -> void:
	for id in _entities.keys():
		despawn_entity(id)
	if is_instance_valid(_level_root):
		_level_root.queue_free()
	_level_root = null
	current_level_id = &""
#endregion
#region 时间入口
## 测试可关闭 set_physics_process(false) 后显式推进，不允许递归重入。
func advance_physics(unscaled_delta: float) -> void:
	if not _configured or _advancing:
		return
	_advancing = true
	## 输入识别/缓存使用未缩放时间；动作执行继续只消费 combat delta。
	for entity in _entities.values():
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() and entity.has_method("advance_input"):
			entity.advance_input(unscaled_delta)
	var delta := clock.advance(unscaled_delta, is_inside_tree() and get_tree().paused)
	if delta > 0.0:
		for entity in _entities.values():
			if is_instance_valid(entity) and not entity.is_queued_for_deletion():
				entity.advance_simulation(delta)
	_advancing = false

func is_simulation_blocked() -> bool:
	return not _configured or clock.paused or clock.time_scale <= 0.0 or clock.hit_stop_remaining > 0.0 or (is_inside_tree() and get_tree().paused)

func set_paused(value: bool) -> void:
	clock.paused = value
	_refresh_operation_control()
	publish_event(&"battle.pause_changed", null, null, {"paused": value})

func set_time_scale(value: float) -> bool:
	if not clock.set_time_scale(value):
		return false
	_refresh_operation_control()
	publish_event(&"battle.time_scale_changed", null, null, {"time_scale": value})
	return true

func request_hit_stop(seconds: float) -> void:
	clock.request_hit_stop(seconds)

func _refresh_operation_control() -> void:
	# 控制权变更立即同步，避免菜单关闭至下一 tick 之间丢失新按下。
	for entity in _entities.values():
		if is_instance_valid(entity) and not entity.is_queued_for_deletion() and entity.has_method("advance_input"):
			entity.advance_input(0.0)
#endregion
#region Core 战斗事件
## 无第二套事件总线；Core 按名订阅仍接收一个 Dictionary，伤害对象保持同步引用。
func publish_event(event_id: StringName, source: Node = null, target: Node = null, data: Dictionary = {}) -> void:
	if not _configured:
		return
	_event_sequence += 1
	var context := data.duplicate()
	context["battle_id"] = battle_id
	context["sequence"] = _event_sequence
	context["physics_tick"] = clock.physics_tick
	context["combat_time"] = clock.elapsed
	context["source_entity_id"] = source.get("entity_id") if is_instance_valid(source) else &""
	context["target_entity_id"] = target.get("entity_id") if is_instance_valid(target) else &""
	if is_instance_valid(target) or is_instance_valid(source):
		context["entity"] = target if is_instance_valid(target) else source
	else:
		context.erase("entity")
	CoreSystem.event_bus.push_event(String(event_id), [context], true)

func _on_core_event(event_id: String, payload: Array) -> void:
	if event_id.begins_with("battle.") or payload.size() != 1 or not payload[0] is Dictionary:
		return
	var context: Dictionary = payload[0]
	var entity: Variant = context.get("entity")
	if not (entity is BattleEntity or entity is BattleEntity2D) or entity.session != self:
		return
	var source: Node = entity
	var info: DamageInfo = context.get("damage_info") as DamageInfo
	if info != null and (info.instigator is BattleEntity or info.instigator is BattleEntity2D):
		source = info.instigator
	publish_event(StringName("battle.gas." + event_id), source, entity, context)

func _on_entity_exiting(id: StringName) -> void:
	_entities.erase(id)
#endregion
