extends Node
#region 最新关卡：只读预热、独立实例、反馈池和死亡释放
var checks: int = 0
var failures: Array[String] = []
var level: Node2D
var session: BattleSession

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func step(delta: float) -> void:
	await get_tree().physics_frame
	session.advance_physics(delta)

func _ready() -> void:
	level = load("res://game/levels/biyujing.tscn").instantiate()
	level.enable_player_controls = false
	add_child(level)
	session = level.session
	session.set_physics_process(false)
	level.flow.stop()
	await get_tree().process_frame
	var parsed := BattleProtectionSystem.source_parse_count
	check(parsed > 0,"保护配置在关卡加载阶段预热")
	var presentation := session.presentation
	var baseline := session.get_entities().size()
	var initial_views := presentation.feedback_created
	var samples: Array[float] = []
	for index in range(20):
		var start := Time.get_ticks_usec()
		var actor := session.spawn_entity_2d("monsters",&"剑舞",Vector2(1200,1056),&"",true)
		samples.append((Time.get_ticks_usec()-start)/1000.0)
		actor.ai_controller.enabled = false
		check(actor.is_spawning() and actor.is_alive(),"缓存优化不跳过出场动画或初始化")
		check(BattleProtectionSystem.source_parse_count == parsed,"刷怪不重复解析2MB保护表")
		var view := actor.feedback
		session.despawn_entity(actor.entity_id)
		check(not view.visible and not view.appearance.visible and not view.hit_effect.visible,"回收清理血条、出场和命中特效")
		await get_tree().process_frame
	check(presentation.feedback_created == initial_views and presentation.feedback_reused >= 20,"连续出生复用预热反馈，没有反复创建表现节点")
	var first := session.spawn_entity_2d("monsters",&"剑舞",Vector2(1300,1056))
	var second := session.spawn_entity_2d("monsters",&"剑舞",Vector2(1350,1056))
	first.ai_controller.enabled = false
	second.ai_controller.enabled = false
	var health := second.attributes.get_vital_value(&"health")
	first.attributes.modify_vital(&"health",-1)
	first.protection.hit_counts["verification"] = 7
	first.protection.score = 123
	check(second.attributes.get_vital_value(&"health") == health and second.protection.score == 0 and second.protection.hit_counts.is_empty(),"缓存不会共享生命、保护值或命中计数")
	var context := {"ability_id":&"sunwukong_attack1"}
	var parameters := first.protection.get_skill_parameters(context)
	var expected := second.protection.get_skill_parameters(context)
	parameters["protectPoint"] = -999
	check(second.protection.get_skill_parameters(context) == expected,"技能结算参数副本不会改写共享保护定义")
	var retired_id := first.entity_id
	var retired_ref: WeakRef = weakref(first)
	first.attributes.get_vital(&"health").set_current_value(0)
	session.set_paused(true)
	await step(10)
	check(session.get_entity(retired_id) == first,"暂停不提前清理尚在播放死亡动作的实体")
	session.set_paused(false)
	await step(10)
	check(session.get_entity(retired_id) == null and not presentation._views.has(retired_id),"死亡动作结束后退出实体索引与活动反馈列表")
	await get_tree().process_frame
	check(retired_ref.get_ref() == null,"死亡怪物及其组件真正释放，不只隐藏")
	session.despawn_entity(second.entity_id)
	await get_tree().process_frame
	check(session.get_entities().size() == baseline,"多次生成与死亡之后活动实体数量恢复基线")
	# Boss视图关闭头顶条，归池后普通怪物必须恢复原设置。
	var boss := session.spawn_entity_2d("monsters",&"巨石灵君",Vector2(1400,1056))
	var boss_view := boss.feedback
	check(not boss_view.health_bar_enabled,"Boss只使用公共Boss血条")
	session.despawn_entity(boss.entity_id)
	await get_tree().process_frame
	var monster := session.spawn_entity_2d("monsters",&"剑舞",Vector2(1400,1056))
	check(monster.feedback == boss_view and monster.feedback.health_bar_enabled,"Boss反馈复用为普通怪物时恢复头顶血条设置")
	session.despawn_entity(monster.entity_id)
	await get_tree().process_frame
	check(presentation._idle_views.size() <= presentation.max_cached_feedback,"空闲反馈缓存有上限")
	samples.sort()
	print("PERF warmed monster spawn ms: median=%.3f max=%.3f; protection_parses=%d feedback_created=%d feedback_reused=%d" % [samples[floori(samples.size()/2.0)],samples[-1],parsed,presentation.feedback_created,presentation.feedback_reused])
	level.free()
	await get_tree().process_frame
	if failures.is_empty(): print("PASS monster spawn/lifetime performance: %d checks" % checks)
	else:
		for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)
#endregion
