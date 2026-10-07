extends Node
#region 验证状态
const MANIFEST := "res://data/battle/manifest.json"
const STEP := 1.0 / 60.0
var _failed := false
var _markers: Array[Dictionary] = []
var _events: Array[Dictionary] = []
var _sessions: Array[BattleSession] = []
#endregion
#region 验证入口
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	CoreSystem.event_bus.subscribe("battle.skill.marker", _on_marker)
	CoreSystem.event_bus.subscribe("battle.gas.damage_received", _on_event)
	CoreSystem.event_bus.subscribe("battle.gas.ability_activated", _on_event)
	var session := _create_session()
	if session == null:
		_finish()
		return
	_check_catalog(session)
	var first := session.spawn_entity("characters", &"sample_hero", Vector3(-5, 0, 0))
	var second := session.spawn_entity("characters", &"sample_hero", Vector3(5, 0, 0))
	if first == null or second == null:
		_check(false, "两个同配置实体应能生成：" + session.last_error)
		_finish()
		return
	_check(first.entity_id != second.entity_id, "同配置实体必须有不同运行 ID")
	_check(first.definition_id == second.definition_id, "两个实体引用同一配置 ID")
	_check(session.get_entity(first.entity_id) == first, "运行 ID 应能定位实体")
	_check(first.attributes.get_vital_value(&"health") == 100.0, "角色初始生命应来自定义")
	_check(first.attributes.get_vital(&"health") != second.attributes.get_vital(&"health"), "Vital 必须独立")
	var first_ability := first.abilities.get_ability_instance(&"sample_attack")
	var second_ability := second.abilities.get_ability_instance(&"sample_attack")
	_check(first_ability != second_ability, "技能实例必须独立")
	first.abilities.disable_ability(&"sample_attack")
	_check(first_ability.disabled and not second_ability.disabled, "禁用状态不能写入另一个技能实例")
	first.abilities.enable_ability(&"sample_attack")
	var guard := first.apply_status_definition(&"sample_guard")
	_check(guard != null and not second.statuses.has_status(&"sample_guard"), "状态容器必须独立")
	_check(first.statuses.get_random_status() == guard, "GAS 随机状态选择应通过战斗宿主随机入口")
	var second_guard := second.apply_status_definition(&"sample_guard")
	_check(guard != second_guard, "同配置状态实例必须独立")
	second.statuses.apply_status(second_guard.status_data, second, 1)
	_check(guard.stacks == 1 and second_guard.stacks == 2, "叠层不能修改另一实体")
	var info := DamageInfo.new(second, null, 20.0)
	info.final_damage = 20.0
	var damage: float = (first.attributes.get_vital(&"health") as HealthVital).apply_damage(info, first)
	_check(is_equal_approx(damage, 10.0), "只有受伤实体的减伤状态可修改同步 DamageInfo")
	_check(first.attributes.get_vital_value(&"health") == 90.0, "受伤实体应扣血")
	_check(second.attributes.get_vital_value(&"health") == 100.0, "另一实体生命不受伤害影响")
	_check(first.try_activate_skill(&"sample_attack"), "技能应可激活")
	session.advance_physics(STEP)
	var cooldown := first_ability.get_feature("CooldownFeature") as CooldownFeature
	var other_cooldown := second_ability.get_feature("CooldownFeature") as CooldownFeature
	_check(cooldown.get_cooldown_remaining(first_ability) == 2.0, "冷却应由 GAS 行为树提交")
	_check(other_cooldown.get_cooldown_remaining(second_ability) == 0.0, "另一实体冷却独立")
	first.velocity = Vector3(3, 0, 0)
	var frozen := _state(first, guard, cooldown, first_ability, session)
	session.set_paused(true)
	for index in 120:
		session.advance_physics(STEP)
	await get_tree().create_timer(0.05).timeout
	_check(_state(first, guard, cooldown, first_ability, session) == frozen, "暂停应冻结生命恢复、Buff、冷却、技能、移动与时间")
	_check(not second.try_activate_skill(&"sample_attack"), "暂停时不能启动新技能")
	session.set_paused(false)
	session.advance_physics(STEP)
	_check_close(session.clock.elapsed - frozen.time, STEP, "恢复应从原时间连续推进，无补算暂停积压")
	_check_close(first.position.x - frozen.position.x, 3.0 * STEP, "位移应按固定物理时间推进")
	var before_slow := _state(first, guard, cooldown, first_ability, session)
	session.set_time_scale(0.5)
	for index in 6:
		session.advance_physics(STEP)
	_check_close(session.clock.elapsed - before_slow.time, 0.05, "慢动作应统一推进 0.05 秒")
	_check_close(before_slow.cooldown - cooldown.get_cooldown_remaining(first_ability), 0.05, "冷却应受慢动作影响")
	_check_close(before_slow.buff - guard.remaining_duration, 0.05, "Buff 应受慢动作影响")
	_check_close(first.attributes.get_vital_value(&"health") - before_slow.health, 0.1, "恢复应受慢动作影响")
	_check_close(first.position.x - before_slow.position.x, 0.15, "移动应受慢动作影响")
	session.request_hit_stop(0.1)
	var before_stop := _state(first, guard, cooldown, first_ability, session)
	for index in 6:
		session.advance_physics(STEP)
	_check_close(session.clock.elapsed, before_stop.time, "受击停顿应冻结战斗时间")
	_check_close(cooldown.get_cooldown_remaining(first_ability), before_stop.cooldown, "受击停顿冻结冷却")
	_check_close(guard.remaining_duration, before_stop.buff, "受击停顿冻结 Buff")
	_check(first.position.is_equal_approx(before_stop.position), "受击停顿冻结位移")
	session.advance_physics(STEP)
	_check_close(session.clock.elapsed - before_stop.time, STEP * 0.5, "停顿到期后恢复慢动作，不重置时间")
	get_tree().paused = true
	var tree_pause_time := session.clock.elapsed
	session.advance_physics(0.5)
	await get_tree().process_frame
	_check_close(session.clock.elapsed, tree_pause_time, "SceneTree 暂停也应冻结战斗")
	get_tree().paused = false
	session.set_time_scale(1.0)
	while session.clock.elapsed + 0.000000001 < 0.4:
		session.advance_physics(minf(STEP, 0.4 - session.clock.elapsed))
	_check(_markers.size() == 1 and _markers[0].source_frame == 12, "30 fps 素材第 12 帧应在技能时间 0.4 秒触发一次")
	if not _markers.is_empty():
		_check_close(_markers[0].skill_time, 0.4, "原始帧时间不可使用物理 tick 号")
		_check(_markers[0].source_entity_id == first.entity_id, "帧事件应保留来源实体运行 ID")
	session.advance_physics(0.7)
	_check(_markers.size() == 2 and _markers[1].source_frame == 18, "跨帧更新应补发尚未触发的素材事件")
	_check(not first_ability.is_active, "素材技能应结束")
	_check(_events.size() >= 2, "GAS 事件应同步转为带战斗上下文的 Core 事件")
	for event in _events:
		_check(event.battle_id == session.battle_id and event.sequence > 0, "战斗事件应携带场次与序号")
	_check_random()
	_check_clock_edges()
	_check_behavior_wait(first)
	_check_equipment(session)
	_check_cached_definitions()
	await _check_automatic_physics()
	_finish()
#endregion
#region 独立验证
func _create_session() -> BattleSession:
	var session := BattleSystem.create_session(self, MANIFEST, 4399)
	_check(session != null, "BattleSystem 应成功加载配置")
	if session != null:
		session.set_physics_process(false)
		_sessions.append(session)
	return session

func _check_catalog(session: BattleSession) -> void:
	for category in BattleCatalog.CATEGORIES:
		_check(session.catalog.get_ids(category).size() == 1, "定义类别应有一个示例：" + category)
	var file := FileAccess.open("user://stage_one_invalid_manifest.json", FileAccess.WRITE)
	file.store_string('{"version":1,"definitions":{"characters":{"bad":"res://missing.tres"}}}')
	file.close()
	_check(not session.catalog.load_manifest("user://stage_one_invalid_manifest.json"), "无效索引应加载失败")
	_check(session.catalog.has_definition("characters", &"sample_hero"), "加载失败不能清空有效索引")
	var copy := session.catalog.instantiate_definition("characters", &"sample_hero") as BattleEntityDefinition
	copy.faction_id = &"changed"
	var fresh := session.catalog.instantiate_definition("characters", &"sample_hero") as BattleEntityDefinition
	_check(fresh.faction_id == &"player", "索引不能向业务暴露共享可变定义")
	DirAccess.remove_absolute("user://stage_one_invalid_manifest.json")

func _check_random() -> void:
	var first := BattleRandom.new()
	var second := BattleRandom.new()
	first.initialize(4399)
	second.initialize(4399)
	for index in 10:
		first.random_int(0, 100, &"loot")
		_check(first.random_int(0, 10000) == second.random_int(0, 10000), "掉落流不能影响战斗随机流")
	var saved := first.snapshot()
	var expected := first.random_int(0, 10000)
	first.restore(saved)
	_check(first.random_int(0, 10000) == expected, "随机状态快照应恢复下一次结果")

func _check_clock_edges() -> void:
	var clock := BattleClock.new()
	clock.set_time_scale(0.5)
	clock.request_hit_stop(0.1)
	_check_close(clock.advance(0.15), 0.025, "一个 tick 内停顿到期只推进剩余时间")
	_check(not clock.set_time_scale(-1.0) and not clock.set_time_scale(NAN), "非法缩放应被拒绝")
	_check_close(clock.advance(-1.0), 0.0, "负时间不应推进")
	clock.request_hit_stop(1.0)
	clock.paused = true
	clock.advance(1.0)
	_check_close(clock.hit_stop_remaining, 1.0, "菜单暂停应冻结停顿剩余时长")

func _check_equipment(session: BattleSession) -> void:
	var first := session.create_equipment(&"sample_sword")
	var second := session.create_equipment(&"sample_sword")
	_check(first.instance_id != second.instance_id, "同配置装备应有独立实例 ID")
	first.durability = 20.0
	first.definition.attribute_modifiers[0].value = 99.0
	_check(second.durability == 100.0 and second.definition.attribute_modifiers[0].value == 5.0, "装备耐久与外部子资源必须隔离")

func _check_behavior_wait(owner: Node) -> void:
	var wait := BTWait.new()
	wait.duration = 0.1
	var tree := BTInstance.new(owner, wait)
	_check(tree.tick(0.04) == BTNode.Status.RUNNING, "BTWait 应累计战斗 delta")
	_check(tree.tick(0.04) == BTNode.Status.RUNNING, "BTWait 不应提前结束")
	_check(tree.tick(0.03) == BTNode.Status.SUCCESS, "BTWait 应由战斗 delta 到期，无须等待真实时间")

func _check_cached_definitions() -> void:
	var hero := load("res://data/battle/characters/sample_hero.tres") as BattleEntityDefinition
	var skill := load("res://data/battle/skills/sample_attack.tres") as GameplayAbilityDefinition
	var guard := load("res://data/battle/statuses/sample_guard.tres") as GameplayStatusData
	_check(hero.faction_id == &"player", "共享角色定义不可被改变")
	_check(not skill.disabled and (skill.features[0] as CooldownFeature).cooldown_duration == 2.0, "共享技能定义不可保存运行时禁用或冷却")
	_check(guard.duration == 3.0 and guard.max_stacks == 3, "共享状态定义不可保存运行时计时或层数")

func _check_automatic_physics() -> void:
	var session := _create_session()
	if session == null:
		return
	_check(session.start_level(&"sample_arena"), "关卡应能读取出生配置")
	_check(session.get_entities().size() == 2, "示例关卡应生成角色和怪物")
	var entities := session.get_entities()
	var hero := entities[0] as BattleEntity
	var monster := entities[1] as BattleEntity
	_check(session.factions.is_hostile(hero.faction_id, monster.faction_id), "玩家与怪物应敌对")
	_check(session.factions.get_relation(&"player", &"neutral") == BattleFactions.Relation.NEUTRAL, "默认中立关系不能自动敌对")
	## 真实物理空间中验证缩放位移仍经过碰撞检测。
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 1, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 2, 4)
	shape.shape = box
	wall.add_child(shape)
	session.add_child(wall)
	await get_tree().physics_frame
	hero.velocity = Vector3(4, 0, 0)
	for index in 60:
		session.advance_physics(STEP)
	_check(hero.position.x < -0.5 and hero.position.x > -0.7, "固定物理位移应被墙体阻挡")
	hero.velocity = Vector3.ZERO
	session.set_physics_process(true)
	var before := session.clock.physics_tick
	for index in 6:
		await get_tree().physics_frame
	_check(session.clock.physics_tick > before and session.clock.elapsed > 0.0, "真实固定物理更新应驱动战斗时钟")
	session.set_paused(true)
	var paused_time := session.clock.elapsed
	for index in 3:
		await get_tree().physics_frame
	_check_close(session.clock.elapsed, paused_time, "真实物理更新期间暂停仍应冻结")
	session.set_paused(false)
	for index in 3:
		await get_tree().physics_frame
	_check(session.clock.elapsed > paused_time, "真实物理更新期间应能恢复")
	session.set_physics_process(false)
	var runtime_id := hero.entity_id
	session.despawn_entity(runtime_id)
	_check(session.get_entity(runtime_id) == null, "销毁实体应立即注销运行 ID")
	var replacement := session.spawn_entity("characters", &"sample_hero")
	_check(replacement.entity_id != runtime_id, "销毁后的运行 ID 不可复用")
#endregion
#region 工具与结果
func _state(entity: BattleEntity, guard: GameplayStatusInstance, cooldown: CooldownFeature, ability: GameplayAbilityInstance, session: BattleSession) -> Dictionary:
	return {"time": session.clock.elapsed, "position": entity.position, "health": entity.attributes.get_vital_value(&"health"), "buff": guard.remaining_duration, "cooldown": cooldown.get_cooldown_remaining(ability), "skill_time": ability.get_blackboard_var("BattleFrameTimelineFeature_elapsed", 0.0)}

func _on_marker(context: Dictionary) -> void:
	_markers.append(context.duplicate())

func _on_event(context: Dictionary) -> void:
	_events.append(context.duplicate())

func _check_close(actual: float, expected: float, message: String) -> void:
	_check(absf(actual - expected) < 0.00001, "%s：实际 %s，期望 %s" % [message, actual, expected])

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

func _finish() -> void:
	get_tree().paused = false
	CoreSystem.event_bus.unsubscribe("battle.skill.marker", _on_marker)
	CoreSystem.event_bus.unsubscribe("battle.gas.damage_received", _on_event)
	CoreSystem.event_bus.unsubscribe("battle.gas.ability_activated", _on_event)
	for session in _sessions:
		session.clear_battle()
		session.queue_free()
	_events.clear()
	_markers.clear()
	await get_tree().process_frame
	CoreSystem.event_bus.clear_event_history()
	if not _failed:
		print("PASS: 阶段1配置/资源索引、实体ID/阵营、双实例隔离、Core战斗事件、随机流/快照、物理时钟、素材帧、暂停/恢复/慢动作/受击停顿")
	get_tree().quit(1 if _failed else 0)
#endregion
