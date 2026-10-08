extends Node
#region 独立预置场景夹具与事件记录
const SKILL := &"sunwukong_timeline_attack"
var demo: Node2D
var player: BattleEntity2D
var target: BattleEntity2D
var session: BattleSession
var hits: Array[Dictionary] = []
var reactions: Array[Dictionary] = []
var finishes: Array[Dictionary] = []
var spawns: Array[Dictionary] = []
var failures: Array[String] = []
var checks: int = 0
var cancel_on_hit: bool = false
var cancel_on_open: bool = false
var restart_on_finished: bool = false

func _ready() -> void:
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	await _fresh()
	await _verify_three_segments()
	await _verify_reentry_and_targets()
	await _verify_low_fps()
	await _verify_sustained()
	await _verify_cancel()
	await _verify_branch()
	await _verify_operation_entry()
	await _verify_cost_clock_and_isolation()
	await _verify_motion_edges()
	await _verify_status_and_reactions()
	CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	player = null
	demo.free()
	if failures.is_empty():
		print("PASS stage 7: %d checks; segmented damage/reactions, low-FPS chronological replay, sustained per-target timing, branch buffer, cancel cleanup, GAS costs/cooldown, pause, motion and isolation" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _paths(node: Node) -> Array[String]:
	var result: Array[String] = []
	for child in node.get_children():
		result.append(String(child.name))
		for descendant in _paths(child):
			result.append("%s/%s" % [child.name, descendant])
	return result

func _fresh() -> void:
	player = null
	if is_instance_valid(demo):
		demo.free()
	demo = (load("res://examples/skill_timeline_demo.tscn") as PackedScene).instantiate()
	var authored := _paths(demo)
	add_child(demo)
	_check(_paths(demo) == authored, "阶段7启动复用所有预置节点，只有一个攻击框")
	player = demo.player
	session = demo.session
	session.damage_strategy = SimpleDamageLogic.new()
	target = demo.dummies[1]
	session.set_physics_process(false)
	demo.operations.enabled = false
	demo.operations.controller.set_process_input(false)
	demo.operations.controller.set_process_unhandled_input(false)
	await _step(8)
	hits.clear()
	reactions.clear()
	finishes.clear()
	spawns.clear()
	cancel_on_hit = false
	cancel_on_open = false
	restart_on_finished = false

func _step(count: int, delta: float = 1.0 / 60.0) -> void:
	for index in range(count):
		await get_tree().physics_frame
		session.advance_physics(delta)

func _on_event(id: String, payload: Array) -> void:
	if not is_instance_valid(player) or payload.size() != 1 or not payload[0] is Dictionary or payload[0].get("battle_id") != session.battle_id:
		return
	var data: Dictionary = payload[0]
	if id == "battle.hit.reaction" and data.get("target_entity_id") == target.entity_id:
		reactions.append(data.duplicate(true))
	if data.get("source_entity_id") != player.entity_id:
		return
	match id:
		"battle.attack.hit":
			hits.append(data.duplicate(true))
			if cancel_on_hit:
				player.cancel_skill(&"test_interrupt")
		"battle.attack.finished":
			finishes.append(data.duplicate(true))
			if restart_on_finished:
				restart_on_finished = false
				player.action_state.advance(0.0, player.action_profile, false)
				player.try_activate_skill(SKILL, {"skip_cost": true, "skip_cooldown": true})
		"battle.skill.object_spawned": spawns.append(data.duplicate(true))
		"battle.attack.window_opened":
			if cancel_on_open:
				player.cancel_skill(&"test_window_interrupt")

func _timeline() -> BattleFrameTimelineFeature:
	return player.abilities.get_ability_instance(SKILL).get_feature("BattleFrameTimelineFeature") as BattleFrameTimelineFeature

func _cooldown() -> float:
	var ability := player.abilities.get_ability_instance(SKILL)
	return (ability.get_feature("CooldownFeature") as CooldownFeature).get_cooldown_remaining(ability)
#endregion
#region 三段独立数值、反应、镜像与位移
func _verify_three_segments() -> void:
	var origin := player.position
	_check(player.request_attack(), "普攻操作启动分段技能")
	var cast := player.attack_instance
	_check(cast.phase == &"startup" and cast.windows.is_empty(), "起手独立释放实例，尚未开启判定")
	await _step(8)
	_check(hits.size() == 1 and cast.phase == &"active", "前摇后到达第一命中段")
	_check(target.feedback.get_node("DamageLabel").text == "−11" and target.feedback.get_node("HealthLabel").text == "490 / 500", "临时公式小数内部保留，界面统一舍入为整数")
	_check(absf(player.position.x - origin.x - 9.0) < 0.001, "0—3素材帧位移仅推进窗口内9世界像素（实际%.6f）" % (player.position.x - origin.x))
	await _step(40)
	_check(hits.size() == 3 and reactions.size() == 3, "一次施放包含三个独立伤害段与反应")
	if hits.size() == 3:
		_check(is_equal_approx(hits[0].damage, 10.5) and is_equal_approx(hits[1].damage, 24.0) and is_equal_approx(hits[2].damage, 36.5), "三段倍率0.5/1/1.5与固定附伤0/3/5独立结算")
		_check(hits[0].segment_id == &"hit_1" and hits[1].segment_id == &"hit_2" and hits[2].segment_id == &"hit_3", "事件携带稳定攻击段ID")
		_check(hits[0].attack_id == cast.attack_id and hits[2].attack_id == cast.attack_id, "同一释放实例拥有三个段")
	if reactions.size() == 3:
		_check(reactions[0].knockback_speed == 60.0 and reactions[1].knockback_speed == 120.0 and reactions[2].knockback_speed == 180.0, "三段不同击退速度")
		_check(reactions[2].launch_speed == 220.0 and reactions[2].hit_stun == 0.3, "末段浮空与硬直由技能数据决定")
	_check(cast.phase == &"recovery" and cast.windows.is_empty(), "段结束关闭判定，后摇仍由战斗状态管理")
	_check(target.received_protection == 60.0, "命中保护值按攻击段传递并累积")
	await _step(40)
	_check(not cast.active and cast.phase == &"ended" and cast.hit_count == 3 and cast.hit_targets.size() == 3, "释放结束保留三段命中历史")
	_check(finishes.size() == 1 and finishes[0].hit_count == 3, "一次释放只发一次完成通知，次数是实际命中数")
	_check(player.action_state.current == BattleActionState2D.State.IDLE and player.animation.get_current_action() == &"idle", "后摇结束返回待机")
	_check(not player.get_node("SkillTrail").visible and not player.attack_hitbox.visible, "完成清理拥有的对象和攻击框显示")
	await _fresh()
#endregion
#region 同步完成重新释放与独立目标计时
func _verify_reentry_and_targets() -> void:
	restart_on_finished = true
	player.request_attack()
	var old := player.attack_instance
	await _step(1, 2.0)
	var newer := player.attack_instance
	_check(newer != old and newer.active and player.abilities.get_ability_instance(SKILL).is_active, "完成通知中重新激活同一GAS技能不会被旧end调用关闭")
	_check(newer.elapsed == 0.0 and hits.size() == 3, "旧调用不推进新施放时间轴或执行新事件")
	var stale := _timeline().attack_segments[0].get_payload()
	stale.merge({"attack_id": old.attack_id, "ability_id": SKILL, "skill_time": 4.0 / 30.0, "source_frame": 4, "source_fps": 30.0}, true)
	player.publish_battle_event(&"battle.attack.impact", stale)
	_check(hits.size() == 3 and newer.windows.is_empty(), "旧释放编号的事件不能污染重新施放的窗口")
	await _step(9)
	var object: BattleTimelineObject2D = player.get_node("SkillTrail")
	object.release_cast(old.attack_id)
	_check(object.visible and object.cast_id == newer.attack_id, "旧对象回收回调不能隐藏新施放复用的对象")
	_check(hits.size() == 4 and hits[3].attack_id == newer.attack_id, "重新施放首段按新编号独立命中")
	await _fresh()
	_configure_sustained()
	demo.dummies[0].super_armor = true
	demo.dummies[0].position.x = 1200.0
	player.request_attack()
	await _step(9)
	demo.dummies[0].position.x = player.position.x - 150.0
	await _step(27)
	var right_hits := hits.filter(func(hit: Dictionary): return hit.target_entity_id == target.entity_id)
	var left_hits := hits.filter(func(hit: Dictionary): return hit.target_entity_id == demo.dummies[0].entity_id)
	_check(right_hits.size() == 3 and left_hits.size() == 3, "同段两个目标各自最多三次，不共享计时或次数")
	_check(player.attack_instance.hit_targets.size() == 2 and player.attack_instance.hit_count == 6, "释放、攻击段、目标三层命中记录独立")
	await _fresh()
	player.animation.set_facing(-1)
	target = demo.dummies[0]
	var start := player.position.x
	player.request_attack()
	await _step(88)
	_check(hits.size() == 3 and hits.all(func(hit: Dictionary): return hit.target_entity_id == target.entity_id), "左向三个攻击段均命中左木桩")
	_check(absf(player.position.x - start + 9.0) < 0.01 and reactions.size() == 3 and reactions[2].knockback_speed == -180.0, "朝向同时镜像技能位移、攻击矩形和击退方向（实际%.6f）" % (player.position.x - start))
	await _fresh()
#endregion
#region 跨帧事件重放与持续命中计时
func _verify_low_fps() -> void:
	player.request_attack()
	await _step(1, 1.2)
	_check(hits.size() == 3 and spawns.size() == 2, "单个1.2秒低帧率tick不漏三段伤害或两个对象事件")
	var effect: BattleTimelineObject2D = player.get_node("SkillTrail")
	_check(effect.visible and is_equal_approx(effect.remaining, 0.5 - (1.2 - 26.0 / 30.0)), "低帧率对象只推进生成后时间，不重复消费整份delta")
	if hits.size() == 3:
		_check(hits[0].sample_time < hits[1].sample_time and hits[1].sample_time < hits[2].sample_time, "跨帧命中按素材时间排序")
		_check(is_equal_approx(hits[0].sample_time, 4.0 / 30.0) and is_equal_approx(hits[2].sample_time, 20.0 / 30.0), "命中时间使用素材秒而非物理更新次数")
	_check(is_equal_approx(target.attributes.get_vital_value(&"health"), 429.0), "低帧率三段总伤害与60FPS相同")
	await _step(1, 1.0)
	_check(finishes.size() == 1 and player.attack_instance.windows.is_empty(), "跨过技能结束也正确清理")
	await _fresh()
	player.request_attack()
	await _step(1, 2.0)
	_check(hits.size() == 3 and finishes.size() == 1, "一个tick跨过整段技能仍先结算各段再完成")
	await _fresh()

func _configure_sustained() -> void:
	var timeline := _timeline()
	var segment := timeline.attack_segments[0]
	segment.start_frame = 3
	segment.end_frame = 18
	segment.hit_interval = 0.1
	segment.maximum_hits = 3
	segment.damage_multiplier = 1.0
	segment.knockback_speed = 0.0
	segment.knockback_duration = 0.0
	timeline.attack_segments = [segment]
	timeline.events.clear()
	timeline.branch_windows.clear()
	timeline.motion_windows.clear()
	target.super_armor = true

func _verify_sustained() -> void:
	_configure_sustained()
	player.request_attack()
	var cast := player.attack_instance
	await _step(88)
	_check(hits.size() == 3 and cast.hit_targets.size() == 1 and cast.hit_count == 3, "持续攻击同段同目标最多三次，历史不退化为布尔值")
	if hits.size() == 3:
		_check(is_equal_approx(hits[1].sample_time - hits[0].sample_time, 0.1) and is_equal_approx(hits[2].sample_time - hits[1].sample_time, 0.1), "每个目标独立保存下次允许命中时间")
	var record: Dictionary = cast.hit_targets.get("1/%s" % target.entity_id, {})
	_check(record.get("count") == 3 and is_equal_approx(float(record.get("next_hit_time", 0.0)), 0.4), "目标记录含命中次数和下次命中时间")
	_check(finishes.size() == 1 and finishes[0].hit_count == 3, "持续攻击完成统计包含重复结算")
	await _fresh()
	_configure_sustained()
	player.request_attack()
	await _step(1, 1.4)
	_check(hits.size() == 3 and is_equal_approx(target.attributes.get_vital_value(&"health"), 437.0), "低帧率持续窗口重放三次间隔命中，不只采样tick末尾")
	await _fresh()
	_configure_sustained()
	target.position.x = 1200.0
	player.request_attack()
	await _step(9)
	_check(hits.is_empty(), "目标未进入持续攻击区域时不提前登记")
	target.position.x = player.position.x + 290.0
	await _step(27)
	_check(hits.size() == 3, "持续窗口中途进入也可按独立间隔命中三次")
	if hits.size() == 3:
		_check(hits[1].sample_time - hits[0].sample_time + 0.000000001 >= 0.1 and hits[2].sample_time - hits[1].sample_time + 0.000000001 >= 0.1, "晚进入的目标不会追补进入前的伤害")
	await _fresh()
#endregion
#region 取消、同步重入、死亡与旧实例清理
func _verify_cancel() -> void:
	player.request_attack()
	await _step(9)
	var cast := player.attack_instance
	var object: BattleTimelineObject2D = player.get_node("SkillTrail")
	_check(object.visible and hits.size() == 1, "取消前已生成对象且首段窗口有效")
	player.cancel_skill()
	_check(not cast.active and cast.windows.is_empty() and cast.buffered_operations.is_empty() and cast.owned_objects.is_empty(), "取消一次性清理攻击窗、派生缓存和对象拥有关系")
	_check(not object.visible and object.cast_id.is_empty() and not player.attack_hitbox.visible, "取消后旧对象与攻击框立即不可见")
	_check(player.abilities.get_ability_instance(SKILL).get_blackboard_var("BattleFrameTimelineFeature_pending", [1]).is_empty(), "取消清空GAS黑板待执行事件")
	await _step(1, 2.0)
	_check(hits.size() == 1 and spawns.size() == 1 and finishes.size() == 1, "取消后未来攻击段与对象事件不执行")
	await _fresh()
	cancel_on_hit = true
	var later_motion := BattleSkillMotion.new()
	later_motion.start_frame = 12
	later_motion.end_frame = 18
	later_motion.velocity = Vector2(300, 0)
	_timeline().motion_windows.append(later_motion)
	var start_position := player.position.x
	player.request_attack()
	await _step(1, 2.0)
	_check(hits.size() == 1 and spawns.size() == 1 and finishes.size() == 1, "同步首击回调取消阻止同一个低帧率tick的后续段")
	_check(absf(player.position.x - start_position - 9.0) < 0.001, "跨帧取消不提前执行未来位移窗口")
	_check(not player.get_node("SkillTrail").visible and player.attack_instance.windows.is_empty(), "同步取消不遗留对象或窗口")
	await _fresh()
	cancel_on_open = true
	player.request_attack()
	await _step(1, 2.0)
	_check(hits.is_empty() and not player.attack_hitbox.visible, "窗口开启通知中取消不再采样伤害或重建旧框")
	await _fresh()
	player.request_attack()
	await _step(3)
	player.abilities.cancel_ability(SKILL)
	await _step(60)
	_check(hits.is_empty() and finishes.size() == 1 and finishes[0].reason == &"cancelled", "直接GAS取消入口也清理当前释放实例并标记取消")
	await _fresh()
	player.abilities.cancel_ability()
	player.request_attack()
	await _step(9)
	cast = player.attack_instance
	var forgotten := player.abilities.get_ability_instance(SKILL)
	player.abilities.forget_ability(SKILL)
	await _step(60)
	_check(not cast.active and not forgotten.is_active and hits.size() == 1 and not player.get_node("SkillTrail").visible, "遗忘活跃GAS技能同样结束施放并清理对象，空技能取消安全")
	_check(forgotten.get_blackboard().get_var("ability_instance") == null, "遗忘清理实例黑板，断开自身引用")
	await _fresh()
	player.request_attack()
	await _step(9)
	player.receive_damage(10000.0)
	await _step(80)
	_check(hits.size() == 1 and not player.get_node("SkillTrail").visible and player.action_state.current == BattleActionState2D.State.DEAD, "攻击者死亡最高优先级取消剩余所有事件")
	await _fresh()
#endregion
#region 派生窗口与统一操作意图
func _verify_branch() -> void:
	player.request_attack()
	_check(not player.request_attack(), "派生缓存窗口开始前的重复普攻不接受")
	await _step(40)
	var old := player.attack_instance
	_check(player.request_attack(), "第20帧的普攻意图提前8帧缓存")
	_check(old.buffered_operations.has(&"attack"), "派生操作存放于本次释放实例")
	await _step(16)
	_check(not old.active and player.attack_instance != old and player.attack_instance.ability_id == &"sunwukong_attack1", "第28帧派生到已学习的普攻技能")
	_check(player.attack_instance.elapsed == 0.0 and player.abilities.get_ability_instance(&"sunwukong_attack1").is_active, "新技能在旧GAS循环结束后起手，不重复吃整份delta")
	_check(finishes.size() == 1 and finishes[0].reason == &"derived" and old.buffered_operations.is_empty(), "派生清理旧实例并保留派生原因")
	await _step(28)
	_check(hits.size() == 4 and hits[3].attack_id != old.attack_id, "派生攻击重新生成释放编号，不继承旧命中历史")
	await _fresh()
	player.request_attack()
	await _step(40)
	player.request_attack()
	player.cancel_operation_commands()
	await _step(45)
	_check(finishes.size() == 1 and finishes[0].reason == &"completed" and player.attack_instance.ability_id == SKILL, "控制权释放清空派生缓存，不继续连招")
	await _fresh()
	player.request_attack()
	await _step(77)
	_check(not player.request_attack(), "派生结束帧为排他边界，窗口结束后不续连招")
	await _step(10)
	await _fresh()
#endregion
#region 技能槽与菜单的真实Core意图入口
func _verify_operation_entry() -> void:
	demo.operations.enabled = true
	var controller: CoreOperationController = demo.operations.controller
	controller.native_input_enabled = false
	for reason in controller.get_control_blocks():
		controller.set_control_blocked(reason, false)
	controller.pulse_intent(&"skill_1", &"stage7_verification")
	await _step(1)
	_check(player.attack_instance != null and player.attack_instance.ability_id == SKILL and player.action_state.current == BattleActionState2D.State.ATTACK, "技能槽语义意图经Core叶子启动三段技能")
	await _step(39)
	controller.pulse_intent(&"attack", &"stage7_verification")
	await _step(1)
	_check(player.attack_instance.buffered_operations.has(&"attack"), "Core按下普攻意图进入时间轴派生缓存")
	demo.menu.set_open(true)
	_check(player.attack_instance.buffered_operations.is_empty() and session.clock.paused and not controller.has_control(), "菜单打开统一释放控制权并清空派生缓存")
	controller.pulse_intent(&"attack", &"stage7_menu_verification")
	await _step(10)
	_check(hits.size() == 3, "菜单操作不会推进技能或重复发动攻击")
	demo.menu.set_open(false)
	await _step(45)
	_check(finishes.size() == 1 and finishes[0].reason == &"completed", "关闭菜单恢复技能且不执行已释放的派生意图")
	await _fresh()
#endregion
#region GAS消耗、冷却、暂停、慢动作与定义隔离
func _verify_cost_clock_and_isolation() -> void:
	player.attributes.get_vital(&"mana").set_current_value(5.0)
	_check(not player.request_attack() and player.attributes.get_vital_value(&"mana") == 5.0, "不足魔法时起手失败且不扣资源")
	await _fresh()
	player.request_attack()
	await _step(3)
	_check(player.attributes.get_vital_value(&"mana") == 90.0 and player.attack_instance.committed, "GAS VitalCost只提交一次10魔法")
	_check(is_equal_approx(_cooldown(), 0.75), "CooldownFeature从提交时开始按战斗秒推进")
	player.cancel_skill()
	_check(not player.request_attack(), "取消不退还消耗、不清空技能冷却")
	session.set_paused(true)
	var remaining := _cooldown()
	await _step(1, 1.0)
	_check(_cooldown() == remaining, "暂停冻结冷却和技能时间")
	session.set_paused(false)
	session.set_time_scale(0.5)
	await _step(1, 0.4)
	_check(is_equal_approx(_cooldown(), remaining - 0.2), "慢动作统一缩放技能与冷却")
	session.clock.request_hit_stop(0.2)
	remaining = _cooldown()
	await _step(1, 0.1)
	_check(_cooldown() == remaining, "受击停顿冻结技能冷却")
	await _step(1, 2.0)
	_check(_cooldown() == 0.0 and player.request_attack(), "冷却结束后允许再次施放")
	await _fresh()
	var original := load("res://data/battle2d/skill_timeline/three_hit.tres") as GameplayAbilityDefinition
	var template := original.features[1] as BattleFrameTimelineFeature
	_timeline().attack_segments[0].damage_multiplier = 9.0
	_check(template.attack_segments[0].damage_multiplier == 0.5, "实体技能定义是独立深拷贝，不污染磁盘共享资源")
	var definition := session.catalog.instantiate_definition("skills", SKILL) as GameplayAbilityDefinition
	var first := definition.create_instance(player)
	var second := definition.create_instance(player)
	var cooldown := first.get_feature("CooldownFeature") as CooldownFeature
	cooldown.start_cooldown(first, 0.4)
	_check(cooldown.get_cooldown_remaining(second) == 0.0, "共享Feature资源也把冷却写入各自GAS实例黑板")
	var shared_cost := (definition.features[0] as CostFeature).costs[0] as VitalCost
	_check(shared_cost.can_pay(player.abilities, player) and not shared_cost.can_pay(demo.dummies[0].abilities, demo.dummies[0]), "共享VitalCost定义不缓存第一个宿主的魔法组件")
	first.clear_blackboard()
	second.clear_blackboard()
	var invalid := template.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as BattleFrameTimelineFeature
	invalid.attack_segments[1].hit_index = 1
	_check(not invalid.is_configuration_valid(), "拒绝攻击段编号重复，防止命中历史碰撞")
	invalid = template.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as BattleFrameTimelineFeature
	invalid.attack_segments[0].hit_interval = -1.0
	_check(not invalid.is_configuration_valid(), "拒绝无效持续命中间隔")
	await _fresh()
#endregion
#region 时间轴位移碰撞与动画同步
func _verify_motion_edges() -> void:
	player.position.x = 1260.0
	_timeline().motion_windows[0].velocity = Vector2(9000, 0)
	player.request_attack()
	await _step(1, 1.4)
	_check(player.position.x <= 1263.1 and player.motion.on_wall, "低帧率高速技能位移经过扫掠，不穿右墙")
	await _fresh()
	player.request_attack()
	await _step(20)
	_check(player.animation.get_current_action() == &"attack_2" and is_equal_approx(player.animation.get_playback_time(), 2.0 / 30.0), "素材第8帧切动作后动画推进余下时间，与时间轴一致")
	var cast := player.attack_instance
	var elapsed := cast.elapsed
	var position := player.animation.get_playback_time()
	session.set_paused(true)
	await _step(10)
	_check(cast.elapsed == elapsed and player.animation.get_playback_time() == position, "暂停同时冻结技能实例和分段动画")
	session.set_paused(false)
	await _step(5)
	_check(cast.elapsed > elapsed, "恢复后从原技能时间连续推进")
	await _fresh()
#endregion
#region GAS Buff与受击许可
func _verify_status_and_reactions() -> void:
	_timeline().attack_segments[0].status_ids = [&"attribute_test_buff"]
	_timeline().attack_segments[0].sub_skill_id = &"sunwukong_attack1"
	player.request_attack()
	await _step(8)
	_check(target.statuses.get_active_statuses().size() == 1 and target.attributes.get_value(&"hpMax") == 600.0, "攻击段Buff接入现有GameplayStatus/Effect与属性重算")
	_check(hits.size() == 1 and hits[0].sub_skill_id == &"sunwukong_attack1", "命中上下文保留关联子技能ID")
	await _fresh()
	target.super_armor = true
	var origin := target.position.x
	player.request_attack()
	await _step(48)
	_check(hits.size() == 3 and reactions.is_empty() and target.position.x == origin, "霸体保留扣血但拒绝普通攻击的击退与浮空")
	await _fresh()
	target.super_armor = true
	_timeline().attack_segments[2].interrupt_kind = &"launch"
	player.request_attack()
	await _step(40)
	_check(hits.size() == 3 and reactions.size() == 1 and target.velocity.y < 0.0, "配置浮空打断类别可按Core规则穿过普通霸体")
	await _fresh()
#endregion
