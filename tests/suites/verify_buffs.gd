extends Node
#region 验收夹具、事件采集与真实场景
var demo: Node2D
var checks: int = 0
var failures: Array[String] = []
var events: Array[Dictionary] = []

class RecursiveEffect extends GameplayEffect:
	func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
		context["probe"]["count"] += 1
		apply(target, instigator, context)

class PublishProbeEffect extends GameplayEffect:
	func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
		target.session.publish_event(&"battle.passive.probe", instigator, target, context)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _ready() -> void:
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	await _fresh()
	_verify_original_resources()
	await _verify_initial_and_composed_buffs()
	await _verify_attributes_and_stacking()
	await _verify_control_and_tags()
	await _verify_periodic_and_clock()
	await _verify_shields_and_lifesteal()
	await _verify_triggers_and_reflection()
	await _verify_passive_ownership_and_cleanup()
	CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	if is_instance_valid(demo):
		demo.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS stage 10 buffs: %d checks; original source configurations, instance/group policies, atomic attributes, control/tags, low-FPS periods, clocks, shields/lifesteal basis, trigger ownership, reflection recursion, passive forgetting, death/despawn/unload" % checks)
		get_tree().quit()
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _fresh() -> void:
	if is_instance_valid(demo):
		demo.free()
	demo = load("res://tests/fixtures/buff_demo.tscn").instantiate()
	demo.enable_player_controls = false
	add_child(demo)
	demo.session.set_physics_process(false)
	for tick in range(35):
		await get_tree().physics_frame
		demo.session.advance_physics(1.0 / 60.0)
	demo.place_near()
	events.clear()

func _on_event(id: String, payload: Array) -> void:
	if not is_instance_valid(demo) or not is_instance_valid(demo.session) or payload.size() != 1 or not payload[0] is Dictionary or payload[0].get("battle_id") != demo.session.battle_id:
		return
	var row: Dictionary = payload[0].duplicate()
	row["event_id"] = id
	events.append(row)

func _count(id: String, kind: String = "") -> int:
	var count := 0
	for row in events:
		if row.event_id == id and (kind.is_empty() or String(row.get("damage_kind", "")) == kind):
			count += 1
	return count

func _strike(target: BattleEntity2D, source: BattleEntity2D, context: Dictionary = {}) -> DamageInfo:
	var ctx := {"skill_config": {"skillDefault": 1.0}, "random_values": {"calDamage": 0.5, "baojiRatio": 0.5, "calPhysicalDamage": 0.5}, "apply_hit_reaction": false}
	ctx.merge(context, true)
	var info := DamageCalculator.calculate_damage(target, source, ctx)
	target.receive_damage_info(info, &"normal", 60, ctx)
	return info
#endregion
#region 原版配置与属性、覆盖及叠层
func _verify_original_resources() -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/buffs/original_config.json"))
	for id in original:
		var data := demo.session.catalog.instantiate_definition("statuses", StringName(id)) as GameplayStatusData
		var row: Dictionary = original[id]
		_check(data != null and data.get_meta(&"original_buff_id") == row.id, "状态对应原版配置：" + id)
		_check(is_equal_approx(data.duration, float(row.totalTime)) and (data.stacking_policy as BattleOriginalStatusPolicy).replace_rule == int(row.replaceRule), "原版时长与替换策略：" + id)
	_check(demo.get_viewport_rect().size == Vector2(940, 590), "Buff场景沿用原游戏分辨率")

func _verify_attributes_and_stacking() -> void:
	var actor: BattleEntity2D = demo.player
	var peer: BattleEntity2D = demo.dummies[1]
	var instance := actor.apply_status_definition(&"attack_up")
	_check(actor.attributes.get_value(&"atk") == 120, "原版type8：当前攻击100乘0.2，加20")
	_check(peer.attributes.get_value(&"atk") == 0, "同配置目标属性不受污染")
	var result := _strike(peer, actor)
	_check(result.actual_hp_loss == 100, "面板与下一次攻击使用相同加攻值")
	actor.attributes.set_base_value(&"atk", 150)
	_check(actor.attributes.get_value(&"atk") == 170, "已施加原版增量保留20，不重复读取自身Buff攻击")
	actor.statuses.advance_simulation(10.0)
	_check(instance.removed and actor.attributes.get_value(&"atk") == 150, "到期只撤销自己的20点，保留GM修改")
	actor.attributes.set_base_value(&"atk", 100)
	var stack_data := load("res://data/buffs/attack_up.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as GameplayStatusData
	stack_data.stacking_policy = StackingRefreshAndStack.new()
	stack_data.max_stacks = 3
	stack_data.duration = 2.0
	var heal := GE_ModifyVital.new()
	heal.vital_id = &"health"
	heal.amount = 1
	stack_data.apply_effects.append(heal)
	actor.attributes.modify_vital(&"health", -20)
	var hp := actor.attributes.get_vital_value(&"health")
	instance = actor.statuses.apply_status(stack_data, actor)
	actor.statuses.advance_simulation(1.0)
	var same := actor.statuses.apply_status(stack_data, actor)
	_check(same == instance and instance.stacks == 2 and actor.attributes.get_value(&"atk") == 140, "同实例叠到2层，属性只保留40增量")
	_check(instance.remaining_duration == 2.0 and actor.attributes.get_vital_value(&"health") == hp + 1, "刷新时间；叠层不重放瞬时治疗")
	actor.statuses.apply_status(stack_data, actor, 8)
	_check(instance.stacks == 3 and actor.attributes.get_value(&"atk") == 160, "叠层达到上限后不继续加成")
	actor.statuses.remove_status(stack_data.status_id)
	_check(actor.attributes.get_value(&"atk") == 100, "移除叠层属性全部恢复")
	var first := actor.apply_status_definition(&"attack_up")
	var second := actor.apply_status_definition(&"attack_up")
	_check(first.removed and first != second and actor.attributes.get_value(&"atk") == 120, "replaceRule1覆盖旧实例而非叠加")
	var deny := stack_data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as GameplayStatusData
	var policy := BattleOriginalStatusPolicy.new()
	policy.replace_rule = 0
	deny.stacking_policy = policy
	var kept := actor.statuses.apply_status(deny, actor)
	_check(kept == second and actor.attributes.get_value(&"atk") == 120, "replaceRule0拒绝重复")
	policy.replace_rule = 6
	actor.statuses.apply_status(deny, actor)
	_check(second.remaining_duration == 12.0, "replaceRule6累加已有时长")
	actor.statuses.clear_statuses()
	var timed := stack_data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as GameplayStatusData
	policy = BattleOriginalStatusPolicy.new()
	policy.replace_rule = 2
	timed.stacking_policy = policy
	timed.duration = 5
	first = actor.statuses.apply_status(timed, actor)
	actor.statuses.advance_simulation(3)
	timed.duration = 2
	_check(actor.statuses.apply_status(timed, actor) == first and first.remaining_duration == 2.0, "replaceRule2旧经过3秒大于新时长2秒，保持旧Buff")
	timed.duration = 4
	second = actor.statuses.apply_status(timed, actor)
	_check(first.removed and second != first and second.remaining_duration == 4, "replaceRule2旧经过时间小于新时长时覆盖")
	actor.statuses.clear_statuses()
	await get_tree().process_frame
#endregion
#region 眩晕Core状态、无敌与霸体的独立引用
func _verify_control_and_tags() -> void:
	await _fresh()
	var actor: BattleEntity2D = demo.player
	_check(actor.request_attack(), "真实角色先进入攻击")
	actor.apply_status_definition(&"stun")
	_check(actor.action_state.current == BattleActionState2D.State.STUN and (actor.attack_instance == null or not actor.attack_instance.active), "眩晕进入Core STUN并清理技能、窗口和派生")
	_check(not actor.request_attack() and not actor.try_jump() and not actor.action_state.get_permission(&"move", actor.action_profile), "眩晕禁止攻击、跳跃及操作移动")
	_check(not actor.abilities.can_activate_ability(&"sunwukong_attack1") and not actor.abilities.get_ability_instance(&"sunwukong_attack1").try_activate(), "直接调用GAS也不能绕过眩晕")
	_strike(actor, demo.dummies[1], {"apply_hit_reaction": true, "hit_stun": 0.1})
	_check(actor.action_state.current == BattleActionState2D.State.STUN, "普通受击不会提前解除眩晕控制")
	actor.statuses.advance_simulation(1.5)
	_check(not TagManager.has_tag(actor, &"state.stunned") and actor.action_state.current != BattleActionState2D.State.STUN, "眩晕到期解除标签及动作限制")
	var walk := actor.attributes.get_value(&"walkSpeed")
	var run := actor.attributes.get_value(&"runSpeed")
	actor.apply_status_definition(&"slow")
	_check(actor.attributes.get_value(&"walkSpeed") == walk * 0.5 and actor.attributes.get_value(&"runSpeed") == run * 0.5, "原版减速同时影响走路与跑步")
	actor.statuses.advance_simulation(5)
	_check(actor.attributes.get_value(&"walkSpeed") == walk and actor.attributes.get_value(&"runSpeed") == run, "减速结束恢复移速")
	var a := actor.apply_status_definition(&"invulnerable")
	actor.statuses.advance_simulation(1)
	var b := actor.apply_status_definition(&"invulnerable")
	_check(a != b and actor.statuses.get_active_statuses().size() == 2, "原版replaceRule3保留两个独立无敌实例")
	actor.statuses.advance_simulation(1)
	_check(a.removed and not b.removed and TagManager.has_tag(actor, &"state.invulnerable"), "第一份到期仍保留另一份无敌标签")
	_check(actor.apply_status_definition(&"stun", demo.dummies[1]) == null, "无敌阻止外部减益控制")
	var hp := actor.attributes.get_vital_value(&"health")
	var info := _strike(actor, demo.dummies[1])
	_check(info.is_immune and actor.attributes.get_vital_value(&"health") == hp, "无敌不扣血且保留结构化免疫结果")
	actor.statuses.advance_simulation(1)
	_check(not TagManager.has_tag(actor, &"state.invulnerable"), "最后一份无敌到期才移除标签")
	var target: BattleEntity2D = demo.dummies[1]
	target.apply_status_definition(&"super_armor")
	var state := target.action_state.current
	info = _strike(target, actor, {"apply_hit_reaction": true, "hit_stun": 0.4})
	_check(info.actual_hp_loss == 80 and target.action_state.current == state, "霸体阻止硬直但保留普通伤害")
	target.statuses.advance_simulation(1)
	info = _strike(target, actor, {"apply_hit_reaction": true, "hit_stun": 0.4})
	_check(target.action_state.current == BattleActionState2D.State.HURT, "霸体到期恢复受击硬直")
#endregion
#region 周期末点、低帧率、暂停、慢动作、停顿
func _verify_periodic_and_clock() -> void:
	await _fresh()
	var target: BattleEntity2D = demo.dummies[1]
	var instance := target.apply_status_definition(&"poison", demo.player)
	_check(is_equal_approx(instance.remaining_duration, 5.1 - 1.0 / 30.0), "原版isImmediate预推进一个30fps素材帧")
	target.statuses.advance_simulation(6)
	_check(instance.removed and target.attributes.get_vital_value(&"health") == 450 and _count("battle.damage.settled", "periodic") == 5, "低帧率跨越整个中毒补齐5次，每次int(500×2%)=10")
	_check(demo.session.presentation.number_rows.get_active_count() == 5, "持续伤害通过公共表现生成五个独立数字")
	instance = target.apply_status_definition(&"poison", demo.player)
	target.statuses.advance_simulation(3.0)
	var replaced := target.apply_status_definition(&"poison", demo.player)
	_check(instance.removed and replaced != instance, "replaceRule2比较周期nowTime而非累计存活3秒")
	target.apply_status_definition(&"shield")
	target.apply_status_definition(&"invulnerable")
	var protected_hp := target.attributes.get_vital_value(&"health")
	target.statuses.advance_simulation(1.0)
	_check(target.attributes.get_vital_value(&"health") == protected_hp - 10 and target.damage_rules.get_shield_total() == 258, "已存在的原版type5直接修改HP，无敌与普通盾不阻止毒伤")
	target.statuses.clear_statuses()
	var data := load("res://data/buffs/poison.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as GameplayStatusData
	data.duration = 2
	data.initial_update_delta = 0
	instance = target.statuses.apply_status(data, demo.player)
	events.clear()
	target.statuses.advance_simulation(2)
	_check(_count("battle.damage.settled", "periodic") == 2 and instance.removed, "到期边界仍执行最后一次周期效果")
	instance = target.apply_status_definition(&"poison", demo.player)
	var remaining := instance.remaining_duration
	demo.session.set_paused(true)
	demo.session.advance_physics(1)
	_check(instance.remaining_duration == remaining, "暂停冻结Buff计时")
	demo.session.set_paused(false)
	demo.session.request_hit_stop(0.3)
	demo.session.advance_physics(0.3)
	_check(instance.remaining_duration == remaining, "受击停顿冻结Buff计时")
	demo.session.set_time_scale(0.5)
	demo.session.advance_physics(0.2)
	_check(is_equal_approx(instance.remaining_duration, remaining - 0.1), "慢动作使用同一战斗delta")
	demo.session.set_time_scale(1)
	target.statuses.clear_statuses()
	data.duration = 0.1
	var effect := data.features[0] as FeaturePeriodicEffects
	effect.period = 1
	effect.trigger_on_apply = true
	events.clear()
	target.statuses.apply_status(data, demo.player)
	_check(_count("battle.damage.settled", "periodic") == 1, "即时周期选项只触发一次")
	target.statuses.advance_simulation(2)
	_check(_count("battle.damage.settled", "periodic") == 1, "不结算持续时间之外的周期")
#endregion
#region 原版普通盾、真实穿盾与明确吸血基准
func _verify_shields_and_lifesteal() -> void:
	await _fresh()
	var actor: BattleEntity2D = demo.player
	var target: BattleEntity2D = demo.dummies[1]
	var shield := target.apply_status_definition(&"shield")
	_check(target.damage_rules.get_shield_total() == 258, "原版type262固定附盾258")
	var info := _strike(target, actor)
	_check(info.shield_absorbed == 80 and info.actual_hp_loss == 1 and target.damage_rules.get_shield_total() == 178, "普通盾吸收80，沿用原版盾后补1")
	info = _strike(target, actor, {"skill_config": {"skillDefault": 1, "realDamagePercent": 1, "realDamageRatio": 1}})
	_check(info.true_damage == 100 and info.shield_absorbed == 0 and target.damage_rules.get_shield_total() == 178, "纯真实伤害穿透普通盾")
	target.statuses.advance_simulation(2.5)
	_check(shield.removed and target.damage_rules.get_shield_total() == 0, "到期移除剩余护盾")
	actor.attributes.modify_vital(&"health", -100)
	actor.apply_status_definition(&"lifesteal")
	target.apply_status_definition(&"shield")
	info = _strike(target, actor)
	_check(info.lifesteal_basis == 80 and info.lifesteal_requested == 400 and info.actual_hp_loss == 1, "吸血按盾前80乘原版V1=5，独立于实际扣血1")
	_check(info.lifesteal_actual == 100 and actor.attributes.get_vital_value(&"health") == 275, "请求回复400，实际只回复缺少的100")
	actor.attributes.modify_vital(&"health", -100)
	var life := actor.statuses.get_status(&"lifesteal")
	actor.damage_rules.set_source(&"cap_test", {"lifeStealCap": -29990})
	info = _strike(target, actor)
	_check(info.lifesteal_requested == 10, "原版吸血受技能倍率乘V2上限限制")
	actor.damage_rules.remove_source(&"cap_test")
	actor.statuses.advance_simulation(1.5)
	_check(life.removed and actor.damage_rules.get_number(&"lifeStealRatio") == 0, "吸血Buff到期撤销规则来源")
	var hp := actor.attributes.get_vital_value(&"health")
	info = _strike(target, actor)
	_check(info.lifesteal_requested == 0 and actor.attributes.get_vital_value(&"health") == hp, "移除后不残留吸血")
#endregion
#region 原版反伤与统一被动触发
func _verify_triggers_and_reflection() -> void:
	await _fresh()
	var actor: BattleEntity2D = demo.player
	var target: BattleEntity2D = demo.dummies[1]
	actor.apply_status_definition(&"reflection")
	target.apply_status_definition(&"reflection")
	var hp := actor.attributes.get_vital_value(&"health")
	var info := _strike(target, actor)
	_check(info.actual_hp_loss == 80 and actor.attributes.get_vital_value(&"health") == hp - 28, "原版反伤：最终80乘0.35，直接扣28")
	_check(_count("battle.damage.settled", "reflection") == 1, "双方反伤仅产生一次次生结算，无无限反弹")
	_check(GameplayTriggerGuard.depth == 0, "所有嵌套效果退出后恢复深度预算")
	actor.statuses.clear_statuses()
	target.statuses.clear_statuses()
	var reflected := load("res://data/buffs/reflection.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as GameplayStatusData
	(reflected.features[0] as BattleTriggerFeature).allow_secondary_damage = true
	actor.statuses.apply_status(reflected, actor)
	target.statuses.apply_status(reflected, target)
	events.clear()
	_strike(target, actor)
	_check(_count("battle.damage.settled", "reflection") == 2 and GameplayTriggerGuard.depth == 0, "显式允许次生伤害时，同一被动链仍不重复自身，只反弹两次")
	actor.statuses.clear_statuses()
	target.statuses.clear_statuses()
	actor.apply_status_definition(&"passive_hit_poison")
	events.clear()
	_strike(target, actor)
	_check(target.statuses.has_status(&"poison") and not actor.statuses.has_status(&"poison"), "有效命中被动通过来源身份施加到事件目标")
	_check(_count("battle.hit.effective", "attack") == 1 and _count("battle.damage.received", "attack") == 1 and _count("battle.damage.settled", "attack") == 1, "有效命中、结算完成和受击触发各发一次")
	var hit_passive := actor.statuses.get_status(&"passive_hit_poison")
	var hit_trigger := hit_passive.status_data.features[0] as BattleTriggerFeature
	_strike(target, actor)
	_check(int(hit_passive.get_feature_storage(hit_trigger).get("trigger_count", 0)) == 1, "命中被动在自身冷却内不重复触发")
	actor.statuses.advance_simulation(1)
	_strike(target, actor)
	_check(int(hit_passive.get_feature_storage(hit_trigger).get("trigger_count", 0)) == 2, "被动冷却由战斗时钟推进，到期允许新命中触发")
	actor.statuses.clear_statuses()
	target.statuses.clear_statuses()
	actor.apply_status_definition(&"passive_cast_attack")
	_check(actor.request_attack(), "施放真实技能触发被动")
	_check(actor.statuses.has_status(&"attack_up") and actor.attributes.get_value(&"atk") == 120 and _count("battle.skill.cast") == 1, "技能释放触发加攻且不依赖逐技能解释")
	actor.cancel_skill()
	actor.statuses.clear_statuses()
	actor.apply_status_definition(&"passive_low_health_shield")
	actor.attributes.modify_vital(&"health", -actor.attributes.get_vital_value(&"health") + 70)
	_check(actor.statuses.has_status(&"shield") and actor.damage_rules.get_shield_total() == 258, "生命向下跨过30%触发护盾")
	var passive := actor.statuses.get_status(&"passive_low_health_shield")
	var trigger := passive.status_data.features[0] as BattleTriggerFeature
	var trigger_count := int(passive.get_feature_storage(trigger).get("trigger_count", 0))
	actor.attributes.modify_vital(&"health", -1)
	_check(int(passive.get_feature_storage(trigger).get("trigger_count", 0)) == trigger_count, "持续低生命不每帧重复触发阈值被动")
	actor.statuses.clear_statuses()
	actor.apply_status_definition(&"passive_kill_heal")
	var before := actor.attributes.get_vital_value(&"health")
	(target.attributes.get_vital(&"health") as HealthVital).heal(500)
	target.attributes.modify_vital(&"health", -target.attributes.get_vital_value(&"health") + 5)
	info = _strike(target, actor)
	_check(info.actual_hp_loss == 5 and _count("battle.entity.killed") == 1 and actor.attributes.get_vital_value(&"health") == before + 25, "过量伤害只扣5，击杀触发一次回复25")
	var recursive := RecursiveEffect.new()
	var probe := {"count": 0}
	var blocked := GameplayTriggerGuard.blocked_count
	recursive.apply(actor, actor, {"probe": probe})
	_check(probe.count == GameplayTriggerGuard.MAX_DEPTH and GameplayTriggerGuard.blocked_count == blocked + 1 and GameplayTriggerGuard.depth == 0, "错误循环效果也有独立深度兜底")
#endregion
#region 被动技能所有权、死亡、离场与场景卸载
func _verify_passive_ownership_and_cleanup() -> void:
	await _fresh()
	var actor: BattleEntity2D = demo.player
	var config := load("res://data/buffs/attack_up.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as GameplayStatusData
	config.duration = -1
	for id in [&"passive_test_a", &"passive_test_b"]:
		var definition := GameplayAbilityDefinition.new()
		definition.ability_id = id
		var feature := PassiveStatusFeature.new()
		feature.statuses[config] = 1
		definition.features = [feature]
		actor.abilities.learn_ability(definition)
	_check(actor.statuses.get_active_statuses().size() == 2 and actor.attributes.get_value(&"atk") == 144, "不同被动技能各持有自己的Buff；第二份按原版当前攻击120乘20%")
	# 触发派生效果不会继承技能学习时的所有权组，仍使用原版同组覆盖。
	var apply_child := GE_ApplyStatus.new()
	apply_child.status_data = load("res://data/buffs/slow.tres")
	apply_child.apply(actor, actor, {"status_owner_source": &"passive_test_a"})
	apply_child.apply(actor, actor, {"status_owner_source": &"passive_test_b"})
	_check(actor.statuses.get_active_statuses().size() == 3, "派生同组减速来自两个被动也只保留一份")
	actor.statuses.remove_status(&"slow")
	actor.abilities.forget_ability(&"passive_test_a")
	_check(actor.statuses.get_active_statuses().size() == 1 and actor.attributes.get_value(&"atk") == 124, "遗忘A只撤销A的20点，保留B的24点")
	actor.abilities.forget_ability(&"passive_test_b")
	_check(actor.statuses.get_active_statuses().is_empty() and actor.attributes.get_value(&"atk") == 100, "遗忘最后一个被动撤销全部来源")
	var target: BattleEntity2D = demo.dummies[1]
	target.apply_status_definition(&"attack_up")
	target.apply_status_definition(&"shield")
	target.apply_status_definition(&"poison", actor)
	target.receive_damage(10000, actor)
	_check(not target.is_alive() and target.statuses.get_active_statuses().is_empty() and target.damage_rules.get_shield_total() == 0, "死亡立即清理Buff、周期与剩余护盾")
	_check(target.apply_status_definition(&"attack_up") == null, "拒绝向死亡目标施加Buff")
	var live: BattleEntity2D = demo.dummies[0]
	var active := live.apply_status_definition(&"poison", actor)
	var runtime := live.apply_status_definition(&"shield")
	demo.session.despawn_entity(live.entity_id)
	_check(active.removed and runtime.removed and live.statuses.get_active_statuses().is_empty(), "离场同步移除周期与效果，不等下一帧")
	actor.apply_status_definition(&"super_armor")
	var old := actor.statuses.get_status(&"super_armor")
	demo.session.clear_battle()
	_check(old.removed and not TagManager.has_tag(actor, &"state.super_armor"), "清理关卡注销持续标签与状态")
	await get_tree().process_frame
#endregion

#region 初始控制状态与同Buff复合属性来源
func _verify_initial_and_composed_buffs() -> void:
	var definition := demo.session.catalog.instantiate_definition("monsters", &"木桩") as BattleEntityDefinition
	definition.initial_status_ids = [&"stun", &"shield"]
	var actor := definition.scene.instantiate() as BattleEntity2D
	actor.scene_definition_id = &""
	actor.initialize_battle(demo.session, &"initial_buff_probe", definition)
	demo.session.add_child(actor)
	_check(actor.action_state.current == BattleActionState2D.State.STUN and actor.damage_rules.get_shield_total() == 258, "入树前初始化的眩晕和盾在ready后保留，不依赖动态组件")
	actor.statuses.advance_simulation(1.5)
	_check(actor.action_state.current != BattleActionState2D.State.STUN, "初始控制Buff也能正常到期解除")
	actor.cleanup_battle()
	actor.free()
	var data := load("res://data/buffs/attack_up.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as GameplayStatusData
	var defense := GE_OriginalBuffAttribute.new()
	defense.attribute_id = &"phyDef"
	defense.fixed_bonus = 30
	data.apply_effects.append(defense)
	var original_defense: float = demo.player.attributes.get_value(&"phyDef")
	var buff: GameplayStatusInstance = demo.player.statuses.apply_status(data, demo.player)
	_check(demo.player.attributes.get_value(&"atk") == 120 and demo.player.attributes.get_value(&"phyDef") == original_defense + 30, "同一Buff两个原版属性效果均生效，不覆盖兄弟来源")
	demo.player.statuses.remove_instance(buff)
	_check(demo.player.attributes.get_value(&"atk") == 100 and demo.player.attributes.get_value(&"phyDef") == original_defense, "复合Buff移除恢复两个属性")
	# 同一被动的多个Feature使用各自身份；名称仅供编辑显示，不能造成链去重冲突。
	data = GameplayStatusData.new()
	data.status_id = &"compound_passive_probe"
	var cast := BattleTriggerFeature.new()
	cast.trigger_on_events = [&"battle.skill.cast"]
	cast.effects = [PublishProbeEffect.new()]
	var settled := BattleTriggerFeature.new()
	settled.trigger_on_events = [&"battle.passive.probe"]
	var healing := GE_ModifyVital.new()
	healing.vital_id = &"health"
	healing.amount = 10
	settled.effects = [healing]
	data.features = [cast, settled]
	demo.player.attributes.modify_vital(&"health", -20)
	var hp: float = demo.player.attributes.get_vital_value(&"health")
	buff = demo.player.statuses.apply_status(data, demo.player)
	demo.session.publish_event(&"battle.skill.cast", demo.player, demo.player)
	_check(demo.player.attributes.get_vital_value(&"health") == hp + 10, "同一被动两个未命名Feature可顺序嵌套触发，不互相误判递归")
	demo.player.statuses.remove_instance(buff)
	await get_tree().process_frame
#endregion
