extends Node
#region 真实关卡、Core事件和固定时钟
var demo: Node2D
var session: BattleSession
var player: BattleEntity2D
var flow: BattleLevelInstance2D
var rows: Array[Dictionary] = []
var checks := 0
var failures: Array[String] = []

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _ready() -> void:
	CoreSystem.event_bus.event_pushed.connect(_event)
	await _fresh()
	_verify_data()
	await _verify_original_waves()
	await _verify_low_fps()
	await _verify_conditions()
	await _verify_all_regions_and_boss()
	await _verify_cleanup()
	await _verify_isolation()
	CoreSystem.event_bus.event_pushed.disconnect(_event)
	demo.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS stage 12 level progression: %d checks; original TMX/five regions/18 plans, birth-vs-death dependencies, delayed waves, exact low-FPS ordering, gates/camera, Boss/conditions/Core exit, one-shot events, optional plans, isolation and cancellation" % checks)
		get_tree().quit()
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)

func _fresh() -> void:
	if is_instance_valid(demo): demo.free()
	demo = load("res://game/levels/biyujing.tscn").instantiate()
	demo.enable_player_controls = false
	# 玩家与反馈组件可创建运行对象；预置检查限定在地图和关卡控制器。
	var authored_count := _level_node_count(demo)
	add_child(demo)
	session = demo.session
	session.set_physics_process(false)
	player = demo.player
	flow = demo.flow
	player.attributes.set_base_value(&"hpMax", 100000)
	player.attributes.get_vital(&"health").set_current_value(100000)
	player.super_armor = true
	_check(_level_node_count(demo) == authored_count and session.get_entities().size() == 1, "地图、控制器、出生点和出口全部预置，启动不提前生成怪物")
	rows.clear()

func _node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children(): count += _node_count(child)
	return count

func _level_node_count(level: Node) -> int:
	var count := _node_count(level.get_node("BattleSession/LevelInstance"))
	for child in level.get_node("BattleSession/Actors").get_children():
		if child is BattleEntity2D: continue
		count += _node_count(child)
	return count

func _step(delta: float = 1.0 / 60.0) -> void:
	await get_tree().physics_frame
	session.advance_physics(delta)

func _event(id: String, payload: Array) -> void:
	if payload.size() != 1 or not is_instance_valid(session) or payload[0].get("battle_id") != session.battle_id: return
	var data: Dictionary = payload[0]
	if id.begins_with("battle.spawn_plan.") or id.begins_with("battle.region.") or id.begins_with("battle.wave.") or id.begins_with("battle.level."):
		rows.append(dict_row(id, data))
	if id == "battle.spawn_plan.spawned":
		var actor := session.get_entity(data.entity_id) as BattleEntity2D
		if actor.ai_controller != null: actor.ai_controller.enabled = false

func dict_row(id: String, data: Dictionary) -> Dictionary:
	var row := data.duplicate(true)
	row["event"] = id
	return row

func _events(id: String, field: String = "", value: Variant = null) -> int:
	var count := 0
	for row in rows:
		if row.event == id and (field.is_empty() or row.get(field) == value): count += 1
	return count

func _living(plan_id: StringName = &"") -> Array[BattleEntity2D]:
	var result: Array[BattleEntity2D] = []
	for actor in session.get_entities():
		if actor is BattleEntity2D and actor != player and actor.is_alive() and (plan_id.is_empty() or actor.get_meta(&"spawn_plan_id", &"") == plan_id): result.append(actor)
	return result

func _kill(actor: BattleEntity2D) -> void:
	# 刷怪依赖验收先结束视觉出场，再沿实际GAS扣血；出场限制另有完整验收。
	actor._finish_spawn_appearance()
	var before := flow.death_count
	var damage := session.apply_secondary_damage(actor, player, 1000000, &"test")
	_check(not actor.is_alive() and damage.actual_hp_loss > 0 and flow.death_count == before + 1, "真实GAS生命扣除触发唯一死亡统计")
	session.publish_event(&"battle.entity.killed", player, actor)
	_check(flow.death_count == before + 1, "重复Core击杀与Vital通知不重复计数")

func _move_player(x: float, y: float = 1056.0) -> void:
	player.global_position = Vector2(x, y)
	player.velocity = Vector2.ZERO
	player.motion.clear_impulse()
	player.move_axis = 0
	player.running = false

func _replace_definition(data: BattleLevelDefinition) -> void:
	flow.stop()
	_check(flow.start(data), "关卡复用预置组件并载入独立配置图")

func _configuration() -> BattleLevelDefinition:
	return session.catalog.instantiate_definition("levels", &"碧玉径") as BattleLevelDefinition
#endregion
#region 原始数据与错误依赖图
func _verify_data() -> void:
	_check(flow.definition.get_progression_error().is_empty() and flow.regions.size() == 5 and flow.waves.size() == 9 and flow.plans.size() == 18, "原始五区域九波次十八计划")
	var planned := 0
	for plan: BattleSpawnPlanInstance in flow.plans.values(): planned += plan.definition.monster_ids.size()
	_check(planned == 34 and not flow.plans[&"screen1_birth1"].all_dead(), "32小怪、容器、Boss均有计划；未出生不算全死")
	_check(demo.camera.limit_right == 2368, "第一屏镜头右边界按TMX设置")
	var evidence: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/biyujing/progression/original_source.json"))
	_check(evidence.container_death_skill.param.s[0].shootFrame == 25 and evidence.container_death_skill.param.s[0].mid == 10601, "容器死亡第25帧召唤巨石灵君的原版依据")
	var bad := _configuration()
	bad.spawn_plans[0].after_dead_plan_ids = [&"missing"]
	_check("不存在" in bad.get_progression_error(), "缺少前置出生点拒绝加载")
	bad = _configuration()
	bad.spawn_plans[0].after_dead_plan_ids = [&"screen1_birth3"]
	_check("循环" in bad.get_progression_error(), "计划循环依赖拒绝加载")
	bad = _configuration()
	bad.waves[0].after_wave_ids = [bad.waves[1].wave_id]
	_check("循环" in bad.get_progression_error(), "波次与出生计划组成的混合循环拒绝加载")
	bad = _configuration()
	bad.spawn_plans[0].after_dead_plan_ids = [&"screen2_birth5"]
	_check("后续区域" in bad.get_progression_error(), "前区域依赖锁定的后区域拒绝加载")
	bad = _configuration()
	bad.regions[0].wave_ids.append(bad.regions[0].wave_ids[0])
	_check(not bad.get_progression_error().is_empty(), "重复波次归属拒绝加载")
	bad = _configuration()
	bad.condition_ids = [&"机关", &"机关"]
	_check(not bad.get_progression_error().is_empty(), "重复条件声明拒绝加载")
	bad = _configuration()
	bad.condition_ids = [&""]
	_check(not bad.get_progression_error().is_empty(), "空条件声明拒绝加载")
	_check(flow.plans[&"screen1_birth1"].definition.after_dead_plan_ids.is_empty(), "修改独立定义不污染当前关卡")
#endregion
#region 出生完毕、全部死亡、第二波延迟与物理门
func _verify_original_waves() -> void:
	await _step(0.01)
	var first: BattleSpawnPlanInstance = flow.plans[&"screen1_birth1"]
	var third: BattleSpawnPlanInstance = flow.plans[&"screen1_birth3"]
	var gate := demo.get_node("BattleSession/Actors/Gates/Gate1") as BattleRegionGate2D
	_check(flow.regions[0].entered and first.next_due > flow.elapsed and _living().is_empty() and gate.locked, "进入触发区后延迟未出生时仍锁门")
	_check(session.camera_rig.combat_locked, "区域已经触发但怪物尚在延迟出生，横向镜头保持锁定")
	await _step(0.9)
	_check(first.created == 0, "原版首只等待delay+interval")
	await _step(0.1)
	_check(first.created == 1 and not first.generation_complete(), "首只出现，计划仍未出生完毕")
	var locked_center: float = demo.camera.get_screen_center_position().x
	for x in [1800,1000]:
		_move_player(x)
		session.camera_rig.advance_camera(1)
		_check(is_equal_approx(demo.camera.get_screen_center_position().x,locked_center), "当前区域有活怪时向左右走均无法移动镜头")
	_move_player(256)
	_kill(_living(&"screen1_birth1")[0])
	_check(not first.all_dead() and gate.locked, "当前唯一活怪死去，不代表计划完成")
	await _step(1.0)
	_check(first.generation_complete() and first.created == 2 and third.started and third.created == 0, "createAfterPoint依据出生完毕，下一出生点仍等待间隔")
	_kill(_living(&"screen1_birth1")[0])
	await _step(2.0)
	_check(third.created == 2, "驭兽使按计划间隔独立出现")
	for actor in _living(): _kill(actor)
	await _step(0.01)
	_check(_living().is_empty() and flow.waves[&"biyujing_region_1_wave_1"].completed and not flow.regions[0].completed and gate.locked, "第一波全死、第二波尚未出现，出口保持锁定")
	_check(session.camera_rig.combat_locked, "第一波全死但第二波未完成，左右镜头仍锁定")
	_check(flow.plans[&"screen1_birth2"].started and flow.plans[&"screen1_birth4"].started, "指定两个出生点全死触发第二波")
	_move_player(2200)
	player.move_axis = 1
	player.running = true
	await _step(0.4)
	_check(player.global_position.x < 2360 and flow.current_region_index == 0 and demo.camera.limit_right == 2368, "锁定物理门挡住奔跑，镜头不提前扩展")
	_move_player(256)
	await _step(0.6)
	_check(_living().size() == 2 and gate.locked, "第二波首批生成时仍锁门")
	await _step(1.0)
	for actor in _living(): _kill(actor)
	await _step(0.01)
	_check(flow.regions[0].completed and flow.regions[0].exit_open and not gate.locked and gate.shape.disabled, "全部计划及目标完成才打开门与碰撞")
	_check(not session.camera_rig.combat_locked, "全部计划与目标完成后才恢复镜头移动")
	await _step(0.1)
	_check(_events("battle.region.completed", "region_id", &"biyujing_region_1") == 1 and _events("battle.region.exit_opened", "region_id", &"biyujing_region_1") == 1, "区域完成及出口开启只通知一次")
	var camera_before: Vector2 = demo.camera.get_screen_center_position()
	_move_player(1800)
	flow._previous_position.x = 1900
	await _step(0.01)
	_check(flow.current_region_index == 0, "清屏后位于提前范围内反向走不切换区域")
	await _step(0.01)
	_check(flow.current_region_index == 0, "清屏后停在提前范围内不自动推动镜头")
	_move_player(1790)
	await _step(0.01)
	_check(flow.current_region_index == 0, "持续向左仍保持当前已通关区域")
	camera_before = demo.camera.get_screen_center_position()
	_move_player(1800)
	await _step(0.01)
	_check(not flow.regions[0].definition.exit_rect.has_point(player.global_position), "清屏后不用走到旧96像素出口")
	_check(flow.current_region_index == 1 and demo.camera.limit_right == 4544 and _events("battle.region.exited") == 1, "清屏后进入右侧半屏提前解锁镜头，未清屏仍锁定")
	var expected_x := lerpf(camera_before.x,1800.0,1.0-pow(0.8,0.3))
	_check(absf(demo.camera.global_position.x-expected_x) < 0.01, "真实自动出口保留旧中心，再推进0.01秒原版插值，不直接跳到玩家")
	_check(demo.camera.get_screen_center_position().is_equal_approx(demo.camera.global_position), "真实过区的渲染中心不会被新左硬限界瞬移")
	camera_before = demo.camera.get_screen_center_position()
	_move_player(1000)
	await _step(1.0 / 30.0)
	_check(absf(demo.camera.global_position.x - lerpf(camera_before.x,1000.0,0.2)) < 0.01 and demo.camera.global_position.x < camera_before.x, "真实清怪过区后回头，镜头向左平滑跟随人物")
	_check(demo.camera.get_screen_center_position().is_equal_approx(demo.camera.global_position) and demo.camera.limit_left == 0, "已清区域左边界持续开放，实际画面不被新区左限界阻挡")
	_check(flow.current_region_index == 1 and demo.camera.limit_right == 4544 and _events("battle.region.exited") == 1, "反向镜头跟随不重复切区，也不提前解锁后续区域")
	_move_player(2500)
	await _step(0.01)
	_check(flow.regions[1].entered and session.camera_rig.combat_locked, "实际进入第二区触发出生计划后重新锁定左右镜头")
	await _step(1)
	var combat_center := session.camera_rig.center.x
	_move_player(4000)
	await _step(0.1)
	_check(is_equal_approx(session.camera_rig._target().x,3308) and session.camera_rig.center.x >= combat_center, "新区有怪时镜头只完成固定位置过渡，不跟随向右移动")
	_move_player(1000)
	await _step(0.1)
	_check(is_equal_approx(session.camera_rig._target().x,3308), "新区有怪时回头不再拉走战斗镜头")
#endregion
#region 低帧率、暂停、慢动作、停顿和窄触发区
func _verify_low_fps() -> void:
	await _fresh()
	_move_player(100)
	flow._previous_position = player.global_position
	await _step(0.01)
	_check(not flow.regions[0].entered, "窄触发区外不提前触发出生")
	_move_player(400)
	await _step(0.01)
	_check(flow.regions[0].entered, "低帧率跨越窄触发区也能进入")
	var time := flow.elapsed
	session.set_paused(true)
	await _step(10)
	_check(flow.elapsed == time and _living().is_empty(), "暂停不消耗出生等待时间")
	session.set_paused(false)
	session.request_hit_stop(1)
	await _step(1)
	_check(flow.elapsed == time, "受击停顿冻结刷怪")
	session.set_time_scale(0.5)
	await _step(1)
	_check(is_equal_approx(flow.elapsed - time, 0.5), "慢动作只缩放一次出生时钟")
	session.set_time_scale(1)
	await _step(10)
	_check(flow.plans[&"screen1_birth1"].created == 2 and flow.plans[&"screen1_birth3"].created == 2 and flow.plans[&"screen1_birth2"].created == 0, "大delta补发出生完成依赖，死亡依赖不提前激活")
	var order: Array[float] = []
	for row in rows:
		if row.event == "battle.spawn_plan.spawned": order.append(row.scheduled_time)
	var ordered := order.size() == 4
	for index in range(order.size()): ordered = ordered and is_equal_approx(order[index], flow.regions[0].entered_at + index + 1)
	_check(ordered, "跨计划事件按原始到期时刻顺序补发：%s" % str(order))
	await _step(10)
	_check(_events("battle.spawn_plan.spawned") == 4, "补发之后不重复生成")
#endregion
#region 额外条件、非通关出生计划与条件后的延迟
func _verify_conditions() -> void:
	await _fresh()
	var data := _configuration()
	data.condition_ids = [&"机关"]
	data.regions[0].required_conditions = [&"机关"]
	data.waves[1].after_wave_ids = [data.waves[0].wave_id]
	var optional := data.spawn_plans[0].duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as BattleSpawnPlanDefinition
	optional.plan_id = &"optional_pot_fixture"
	optional.participates_in_clear = false
	optional.delay_seconds = 100
	optional.after_dead_plan_ids = [&"screen1_birth2"]
	data.spawn_plans.append(optional)
	data.waves[0].plan_ids.append(optional.plan_id)
	_replace_definition(data)
	await _step(0.01)
	await _step(2.01)
	_check(not flow.waves[data.waves[1].wave_id].started and not _living().is_empty(), "前置波次出生完毕但仍有活怪，依赖波次不能启动")
	await _clear_region(false)
	_check(flow.waves[data.waves[1].wave_id].completed, "前置波次完成后启动下一波，可选计划等待下一波不构成循环死锁")
	_check(flow.waves[&"biyujing_region_1_wave_2"].completed and not flow.regions[0].completed and not flow.regions[0].exit_open, "目标已死但区域机关条件未满足仍锁门")
	_check(not flow.set_condition(&"未声明的条件"), "未知条件拒绝设置")
	_check(flow.set_condition(&"机关"), "条件通过统一关卡入口设置")
	await _step(0.01)
	_check(flow.regions[0].exit_open and flow.plans[optional.plan_id].created == 0, "includeScreen=false语义的可选计划不阻止通关")
	await _step(102)
	var optional_targets := _living(optional.plan_id)
	_check(optional_targets.size() == 2, "可选计划在区域已完成后仍按原定出生时间执行")
	if optional_targets.size() == 2:
		session.despawn_entity(optional_targets[0].entity_id)
		optional_targets[1].free()
	await _step(0.01)
	_check(flow.state == BattleLevelInstance2D.State.RUNNING and flow.death_count == 8 and flow.regions[0].exit_open, "可选目标活着离场或释放不影响通关，也不伪造死亡统计")
	await _fresh()
	data = _configuration()
	data.condition_ids = [&"出生许可"]
	data.spawn_plans[0].required_conditions = [&"出生许可"]
	data.spawn_plans[0].delay_seconds = 0.2
	_replace_definition(data)
	await _step(5)
	_check(flow.plans[&"screen1_birth1"].created == 0, "条件未满足时出生计划不开始")
	flow.set_condition(&"出生许可")
	await _step(1.1)
	_check(flow.plans[&"screen1_birth1"].created == 0, "条件满足后重新计算首只延迟，不追溯到进入区域时")
	await _step(0.1)
	_check(flow.plans[&"screen1_birth1"].created == 1, "条件满足后的delay+interval到期才生成")

func _clear_region(expect_complete: bool = true) -> void:
	var region := flow.regions[flow.current_region_index]
	_move_player(region.definition.entry_rect.get_center().x)
	for iteration in range(32):
		await _step(0.01)
		for actor in _living(): _kill(actor)
		var done := true
		var next := INF
		for wave_id in region.definition.wave_ids:
			var wave: BattleWaveInstance = flow.waves[wave_id]
			for plan_id in wave.definition.plan_ids:
				var plan: BattleSpawnPlanInstance = flow.plans[plan_id]
				if plan.definition.participates_in_clear:
					if not plan.all_dead(): done = false
					next = minf(next, plan.next_due)
		if done:
			await _step(0.01)
			_check(region.completed == expect_complete, "区域出生计划及死亡完成符合额外条件")
			return
		if is_finite(next): await _step(maxf(0.001, next-flow.elapsed))
	_check(false, "区域调度在有限时间内完成")
#endregion
#region 全五区域、容器延迟Boss、最终条件与Core出口操作
func _verify_all_regions_and_boss() -> void:
	await _fresh()
	var data := _configuration()
	data.condition_ids = [&"关卡机关"]
	data.required_conditions = [&"关卡机关"]
	_replace_definition(data)
	for index in range(4):
		await _clear_region()
		_move_player(flow.regions[index].definition.exit_rect.get_center().x)
		_check(flow.request_exit(player) and flow.current_region_index == index+1, "前四区域完成后可进入下一屏")
	var last := flow.regions[4]
	_move_player(last.definition.entry_rect.get_center().x)
	await _step(0.01)
	_check(_living(&"revival_vessel_birth").size() == 1 and _living(&"jushi_lingjun_birth").is_empty(), "原版末区先生成容器，Boss尚未存在")
	await _step(2.01)
	for actor in _living():
		if actor.definition_id != &"复苏容器": _kill(actor)
	_kill(_living(&"revival_vessel_birth")[0])
	await _step(24.0/30.0)
	_check(_living().is_empty() and not last.exit_open and flow.state == BattleLevelInstance2D.State.RUNNING, "容器已死但Boss第25帧尚未到，零活怪不打开出口")
	await _step(1.01/30.0)
	var boss := _living(&"jushi_lingjun_birth")[0]
	_check(boss.definition_id == &"巨石灵君" and boss.attributes.get_value(&"hpMax") == 1167, "真正原版Boss身份、生命与独立实例")
	_kill(boss)
	await _step(0.1) # 斩败按原30Hz抽帧，首个战斗帧需等待两帧。
	_check(last.completed and not last.exit_open and flow.state == BattleLevelInstance2D.State.RUNNING, "Boss死亡后还需要关卡额外条件")
	flow.set_condition(&"关卡机关")
	await _step(0.1)
	_check(last.exit_open and flow.state == BattleLevelInstance2D.State.RUNNING and flow.death_count == 34, "全部计划完成与条件满足后开最终出口，但尚未确认通关")
	await _step(2.1) # 原斩败59帧结束后才允许最终出口操作。
	_move_player(last.definition.exit_rect.get_center().x)
	player.operations.enabled = true
	demo.menu.set_open(true)
	Input.parse_input_event(_key(KEY_W, true))
	await get_tree().process_frame
	await _step()
	Input.parse_input_event(_key(KEY_W, false))
	await get_tree().process_frame
	demo.menu.set_open(false)
	await _step()
	_check(flow.state == BattleLevelInstance2D.State.RUNNING, "菜单内W不会同时确认通关")
	Input.parse_input_event(_key(KEY_W, true))
	await get_tree().process_frame
	await _step()
	Input.parse_input_event(_key(KEY_W, false))
	await get_tree().process_frame
	await _step()
	_check(flow.state == BattleLevelInstance2D.State.WON and _events("battle.level.victory") == 1, "Core上方向意图确认原版最终出口：位置%s，暂停%s，控制%s" % [player.global_position, session.clock.paused, player.operations.controller.has_control()])
	_check(not flow.request_exit(player) and not flow.set_condition(&"关卡机关"), "胜利后不能重复进入出口或修改结算条件")
	await _step(30)
	_check(_events("battle.level.victory") == 1 and _events("battle.region.exit_opened") == 5 and _events("battle.region.completed") == 5 and _events("battle.spawn_plan.all_dead") == 18, "胜利、五区域开门完成与18计划全死通知均恰好一次")

func _key(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event
#endregion
#region 死亡、存活离场、卸载和两个关卡互不污染
func _verify_cleanup() -> void:
	await _fresh()
	await _step(0.01)
	player.attributes.get_vital(&"health").set_current_value(0)
	await _step(10)
	_check(flow.state == BattleLevelInstance2D.State.FAILED and _living().is_empty() and _events("battle.level.failed") == 1, "玩家死亡取消所有待出生事件并只失败一次")
	await _fresh()
	await _step(0.01)
	await _step(1.0)
	session.despawn_entity(_living()[0].entity_id)
	await _step(10)
	_check(flow.state == BattleLevelInstance2D.State.FAILED and flow.death_count == 0 and not flow.regions[0].exit_open, "存活离场不能伪装为死亡或通关")
	await _fresh()
	await _step(0.01)
	await _step(1.0)
	_living()[0].free()
	await _step(10)
	_check(flow.state == BattleLevelInstance2D.State.FAILED and flow.death_count == 0 and _events("battle.level.failed") == 1, "必要目标直接释放同样取消出生、唯一失败且不伪造死亡")
	await _fresh()
	await _step(0.01)
	session.clear_battle()
	await _step(100)
	_check(flow.state == BattleLevelInstance2D.State.STOPPED and flow.plans.is_empty() and session.get_entities().is_empty() and _events("battle.spawn_plan.spawned") == 0, "离开关卡释放运行状态并取消所有延迟生成")
	await _fresh()
	await _step(0.01)
	session.catalog._definitions.monsters.erase(&"剑舞")
	await _step(1)
	_check(flow.state == BattleLevelInstance2D.State.FAILED and not flow.regions[0].exit_open, "运行时出生失败不推进计划或误开门")

func _verify_isolation() -> void:
	await _fresh()
	var other := load("res://game/levels/biyujing.tscn").instantiate() as Node2D
	other.enable_player_controls = false
	add_child(other)
	other.session.set_physics_process(false)
	await _step(0.01)
	await _step(2.0)
	_check(flow.plans[&"screen1_birth1"].created == 2 and other.flow.plans[&"screen1_birth1"].created == 0, "两个同配置关卡的生成游标和时钟独立")
	_check(flow.definition != other.flow.definition and flow.plans[&"screen1_birth1"].definition != other.flow.plans[&"screen1_birth1"].definition, "关卡与出生计划使用独立配置副本")
	other.free()
#endregion
