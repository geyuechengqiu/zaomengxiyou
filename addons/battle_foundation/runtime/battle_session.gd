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
var _damage_serial: int = 0
var _configured: bool = false
var _event_bus: Node
var _level_root: Node
var _advancing: bool = false
var _pending_hit_stop: float = 0.0
## 公共战斗表现必须由场景预置；不挂载于任何角色。
var presentation: BattlePresentation2D:
	get: return get_node_or_null(^"BattlePresentation") as BattlePresentation2D
var level_instance: BattleLevelInstance2D:
	get: return get_node_or_null(^"LevelInstance") as BattleLevelInstance2D
var camera_rig: BattleCameraRig2D:
	get: return get_node_or_null(^"CameraRig") as BattleCameraRig2D
var loot: BattleLootManager2D:
	get: return get_node_or_null(^"Loot") as BattleLootManager2D
var audio: BattleAudio:
	get: return get_node_or_null(^"BattlePresentation/Audio") as BattleAudio
## 可在 .tscn 中预置会话；留空保留原工厂配置方式。
@export_file("*.json") var scene_manifest_path: String = ""
@export var scene_seed: int = 0
## 场景显式选择原版策略，插件独立示例仍可选择 SimpleDamageLogic。
@export var damage_strategy: DamageLogicStrategy
#endregion
#region 固定物理生命周期
func _enter_tree() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_event_bus = CoreSystem.event_bus
	if not _configured and not scene_manifest_path.is_empty():
		var configured := BattleSystem.configure_scene_session(self, scene_manifest_path, scene_seed)
		assert(configured, last_error)
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
	if data.scene == null:
		last_error = "实体定义必须引用预置组件的角色场景：" + str(id)
		return null
	var node: Node = data.scene.instantiate()
	if not node is BattleEntity:
		node.free()
		last_error = "实体场景根节点必须继承 BattleEntity"
		return null
	var entity := node as BattleEntity
	last_error = entity.get_component_configuration_error(data)
	if not last_error.is_empty():
		entity.free()
		return null
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

func spawn_entity_2d(category: String, id: StringName, at: Vector2 = Vector2.ZERO, faction_override: StringName = &"", play_appearance: bool = false) -> BattleEntity2D:
	if not _configured or not ["characters", "monsters"].has(category):
		last_error = "战斗未配置或实体类别无效"
		return null
	var data := catalog.instantiate_definition(category, id) as BattleEntityDefinition
	if data == null:
		last_error = catalog.last_error
		return null
	if data.scene == null:
		last_error = "2D 实体定义必须引用预置组件的角色场景：" + str(id)
		return null
	var node: Node = data.scene.instantiate()
	if not node is BattleEntity2D:
		node.free()
		last_error = "2D 实体场景根节点必须继承 BattleEntity2D"
		return null
	var entity := node as BattleEntity2D
	last_error = entity.get_component_configuration_error(data)
	if not last_error.is_empty():
		entity.free()
		return null
	_entity_serial += 1
	entity.position = at
	var runtime_id := StringName("%s/entity/%d" % [battle_id, _entity_serial])
	entity.initialize_battle(self, runtime_id, data)
	if not faction_override.is_empty():
		entity.faction_id = faction_override
	_entities[runtime_id] = entity
	entity.tree_exiting.connect(_on_entity_exiting.bind(runtime_id), CONNECT_ONE_SHOT)
	add_child(entity)
	if play_appearance and category == "monsters": entity.begin_spawn_appearance(int(data.get_meta(&"original_show_appear", 0)))
	publish_event(&"battle.entity_spawned", null, entity, {"definition_id": id, "category": category})
	return entity

func get_entity(id: StringName) -> Variant:
	return _entities.get(id)

## 只注册已存在的 2D 节点；实体入树时调用，先于动画/反馈/GAS 子节点 ready。
func register_scene_entity_2d(entity: BattleEntity2D, category: String, id: StringName) -> bool:
	if not _configured or not ["characters", "monsters"].has(category) or not entity.entity_id.is_empty():
		last_error = "预置实体需要已配置会话、合法类别且只能注册一次"
		return false
	var data := catalog.instantiate_definition(category, id) as BattleEntityDefinition
	if data == null:
		last_error = catalog.last_error
		return false
	last_error = entity.get_component_configuration_error(data)
	if not last_error.is_empty():
		return false
	_entity_serial += 1
	var runtime_id := StringName("%s/entity/%d" % [battle_id, _entity_serial])
	entity.initialize_battle(self, runtime_id, data)
	_entities[runtime_id] = entity
	entity.tree_exiting.connect(_on_entity_exiting.bind(runtime_id), CONNECT_ONE_SHOT)
	publish_event(&"battle.entity_spawned", null, entity, {"definition_id": id, "category": category, "scene_authored": true})
	return true

func get_entities() -> Array:
	return _entities.values().duplicate()

func despawn_entity(id: StringName) -> void:
	var entity: Variant = get_entity(id)
	if entity == null:
		return
	entity.cleanup_battle()
	publish_event(&"battle.entity_despawned", null, entity)
	if presentation != null:
		presentation.remove_actor(id)
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
	if not data.regions.is_empty() and level_instance == null:
		last_error = "区域关卡必须预置LevelInstance组件"
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
	if not data.regions.is_empty() and not level_instance.start(data):
		last_error = level_instance.last_error
		clear_battle()
		return false
	current_level_id = id
	publish_event(&"battle.level_started", null, null, {"level_id": id})
	return true

## 编辑器预置的2D关卡沿用目录与生命周期，不在启动时创建角色/地形节点。
func register_scene_level(id: StringName, level_root: Node) -> bool:
	if not _configured or not current_level_id.is_empty() or level_root == null or level_root.get_parent() != self:
		last_error = "预置关卡必须直接属于已配置且尚未开始关卡的BattleSession"
		return false
	var data := catalog.instantiate_definition("levels", id) as BattleLevelDefinition
	if data == null:
		last_error = catalog.last_error
		return false
	_level_root = level_root
	if not data.regions.is_empty() and level_instance == null:
		last_error = "区域关卡必须预置LevelInstance组件"
		_level_root = null
		return false
	if level_instance != null and not data.regions.is_empty() and not level_instance.start(data):
		last_error = level_instance.last_error
		_level_root = null
		return false
	current_level_id = id
	publish_event(&"battle.level_started", null, null, {"level_id": id})
	return true

func clear_battle() -> void:
	if loot != null: loot.clear_loot()
	if level_instance != null: level_instance.stop()
	if camera_rig != null: camera_rig.stop()
	for id in _entities.keys():
		despawn_entity(id)
	if is_instance_valid(_level_root):
		_level_root.queue_free()
	_level_root = null
	current_level_id = &""
	if presentation != null:
		presentation.clear_presentations()
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
	# 命中停顿始终消耗未缩放时间，斩败抽帧只过滤随后真正推进的战斗时间。
	var filter := presentation.filter_combat_delta if presentation != null else Callable()
	var delta := clock.advance(unscaled_delta, is_inside_tree() and get_tree().paused, filter)
	if delta > 0.0:
		for entity in _entities.values():
			if is_instance_valid(entity) and not entity.is_queued_for_deletion():
				entity.advance_simulation(delta)
	if is_instance_valid(_level_root) and _level_root is BattleMap2D:
		_level_root.advance_visuals(delta)
	if loot != null: loot.advance_loot(delta)
	if presentation != null:
		presentation.advance_presentation(delta)
		presentation.advance_ui(unscaled_delta if not clock.paused and not (is_inside_tree() and get_tree().paused) else 0.0)
	if level_instance != null:
		level_instance.advance_level(delta)
	if camera_rig != null:
		camera_rig.advance_camera(delta)
	# 同一 tick 的所有目标先完成命中，停顿从下一个物理 tick 开始。
	# 不能让第一个目标请求停顿后，后面的目标因为 blocked 而漏结算。
	if _pending_hit_stop > 0.0:
		clock.request_hit_stop(_pending_hit_stop)
		_pending_hit_stop = 0.0
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
	if _advancing:
		if is_finite(seconds):
			_pending_hit_stop = maxf(_pending_hit_stop, seconds)
	else:
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
	if event_id == "ability_activated":
		publish_event(&"battle.skill.cast", entity, entity, context)
	elif event_id == "damage_applied" and info != null and not bool(info.get_meta(&"reaction_deferred", false)):
		publish_damage_result(info, entity, info.get_meta(&"hit_context", {}))
		if entity.has_method("cleanup_death_statuses"):
			entity.cleanup_death_statuses()

func _on_entity_exiting(id: StringName) -> void:
	if presentation != null:
		presentation.remove_actor(id)
	_entities.erase(id)
#endregion

#region 伤害结果与次生伤害的公共触发入口
func publish_damage_result(info: DamageInfo, target: Node, context: Dictionary = {}) -> void:
	_damage_serial += 1
	var result := context.duplicate()
	result.merge(info.to_dictionary(), true)
	result["damage"] = info.actual_hp_loss
	result["damage_id"] = StringName("%s/damage/%d" % [battle_id, _damage_serial])
	result["damage_kind"] = StringName(context.get("damage_kind", &"attack"))
	result["trigger_chain"] = context.get("trigger_chain", []).duplicate()
	var source: Node = info.instigator if is_instance_valid(info.instigator) else null
	if not info.is_dodged and not info.is_immune and info.final_damage > 0.0:
		publish_event(&"battle.hit.effective", source, target, result)
	publish_event(&"battle.damage.settled", source, target, result)
	if info.actual_hp_loss > 0.0:
		publish_event(&"battle.damage.received", source, target, result)
	if info.hp_before > 0.0 and info.hp_after <= 0.0 and info.actual_hp_loss > 0.0:
		publish_event(&"battle.entity.killed", source, target, result)

## DoT/反伤沿用原版直接扣生命，不再次计算防御、暴击、护盾或吸血。
## 原版反伤使用resolved_damage，属于次生伤害，不重新触发同一被动链。
func apply_secondary_damage(target: Node, source: Node, amount: float, kind: StringName, parent_context: Dictionary = {}) -> DamageInfo:
	var info := DamageInfo.new(source)
	info.single_use = true
	info.final_damage = maxf(0.0, amount)
	info.normal_damage = info.final_damage
	info.calculated_damage = info.final_damage
	var context := {"damage_kind": kind, "trigger_chain": parent_context.get("trigger_chain", []).duplicate(), "source_status_id": parent_context.get("source_id", &""), "apply_hit_reaction": false, "has_hit_effect": false, "reaction_type": &"none", "bypass_armor_multiplier": true, "bypass_damage_policy": kind == &"periodic"}
	if target.has_method("receive_damage_info"):
		target.receive_damage_info(info, &"normal", 0, context)
	return info
#endregion
