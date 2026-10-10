extends Node
#region 验收与固定随机输入
var demo: Node2D
var attacker: BattleEntity2D
var target: BattleEntity2D
var strategy: BattleOriginalDamageStrategy
var checks: int = 0
var failures: Array[String] = []
const RANDOM := {"calDamage": 0.5, "baojiRatio": 0.5, "calPhysicalDamage": 0.5}

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _ready() -> void:
	demo = load("res://tests/fixtures/original_damage_demo.tscn").instantiate()
	demo.enable_player_controls = false
	add_child(demo)
	demo.session.set_physics_process(false)
	attacker = demo.player
	target = demo.dummies[1]
	strategy = demo.session.damage_strategy
	_verify_tables()
	_verify_golden_core()
	_verify_probabilities()
	_verify_growth_and_exclusive()
	_verify_post_order()
	_verify_effect_resources()
	_verify_status_and_hooks()
	await _verify_real_attack()
	demo.session.clear_battle()
	demo.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS stage 8: %d checks; original EXP, fixed RNG golden formulas, ordered callbacks, true damage, shields, GAS effects, actual HP loss and integer UI" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _reset() -> void:
	attacker.damage_rules.clear()
	target.damage_rules.clear()
	for entity in [attacker, target]:
		entity.attributes.set_base_value(&"hpMax", 2000.0)
		entity.attributes.set_base_value(&"atk", 100.0)
		entity.attributes.set_base_value(&"phyDef", 20.0)
		for id in [&"hit", &"dodge", &"critical", &"toughness", &"lucky", &"guardian", &"fireResist"]:
			entity.attributes.set_base_value(id, 0.0)
		(entity.attributes.get_vital(&"health") as HealthVital).heal(2000.0)

func _calc(skill: Dictionary = {}, extra: Dictionary = {}) -> DamageInfo:
	var ctx := {"random_values": RANDOM, "skill_config": skill, "ability_id": &"sunwukong_attack1"}
	ctx.merge(extra, true)
	return DamageCalculator.calculate_damage(target, attacker, ctx)

func _apply(info: DamageInfo) -> float:
	return (target.attributes.get_vital(&"health") as HealthVital).apply_damage(info, target)
#endregion
#region 原版公式黄金样例
func _verify_tables() -> void:
	_check(strategy.get_level_parameters(1).criticalMax == 156.25, "EXP一级分母保留156.25，不向下取整")
	_check(strategy.get_level_parameters(220).hitAttribute == 155064, "导入完整220级换算表")
	_check(strategy.get_level_parameters(221).is_empty(), "未知等级不偷偷使用一级分母")
	for id in range(1, 6):
		var skill := strategy.get_skill_parameters(StringName("sunwukong_attack%d" % id))
		_check(skill.source_skill_id == 1001000 + id * 10, "业务ID独立映射原始普攻配置")
	var copy := strategy.get_level_parameters(1)
	copy.criticalMax = 1
	_check(strategy.get_level_parameters(1).criticalMax == 156.25, "返回配置修改不污染原版表")

func _verify_golden_core() -> void:
	_reset()
	## 黄金值由AS原式手算；固定RNG .5使浮动为1。
	for row in [[{}, {}, 80.0], [{}, {"random_values": {"calDamage": 0.5, "baojiRatio": 0.5, "calPhysicalDamage": 0.0}}, 76.0], [{"skillDefault": 1.5, "skillCountAdd": [7]}, {}, 127.0], [{"skillDefault": 1.2}, {}, 96.0]]:
		_check(is_equal_approx(_calc(row[0], row[1]).calculated_damage, row[2]), "普通/下浮动/固定附伤/技能倍率黄金值")
	attacker.attributes.set_base_value(&"critical", 156.25)
	_check(_calc().is_crit and _calc().calculated_damage == 160.0, "等评分幸运守护：暴击总倍率2")
	attacker.attributes.set_base_value(&"lucky", 156.25)
	_check(_calc().calculated_damage == 240.0, "幸运上限暴击总倍率3")
	target.attributes.set_base_value(&"guardian", 312.5)
	_check(_calc().calculated_damage == 80.0, "守护抵消幸运，暴击下限倍率1")
	attacker.attributes.set_base_value(&"critical", 0.0)
	for resistance in [100.0, -50.0]:
		target.attributes.set_base_value(&"fireResist", resistance)
		_check(_calc({"type": 4}).calculated_damage == (40.0 if resistance > 0 else 120.0), "正/负抗性原式")
	target.attributes.set_base_value(&"fireResist", 100.0)
	_check(_calc({"type": 4, "skillDefault": 0.45, "skillCountAdd": [3]}).calculated_damage == 19.0, "防御基础截断39，再抗性截断19")
	_check(_calc({"type": 4, "skillDefaultRatio": 0.25}).calculated_damage == 50.0, "额外倍率在抗性截断之后")
	target.attributes.set_base_value(&"phyDef", 200.0)
	_check(_calc().calculated_damage == 1.0, "减法防御最低核心伤害1")
#endregion
#region 概率、成长和专属入口
func _verify_probabilities() -> void:
	_reset()
	target.damage_rules.set_source(&"dodge", {"fixedDodgeRate": 1.0})
	var info := _calc({}, {"random_values": {"calDamage": 0.0}})
	_check(info.is_dodged and info.calculated_damage == 0.0, "命中率零时随机零仍闪避")
	_check(info.trace.filter(func(row: Dictionary) -> bool: return row.stage == &"random").size() == 1, "闪避只消费命中随机，不消费暴击和浮动")
	_check(not _calc({}, {"cannot_dodge": true}).is_dodged, "不可闪避保留命中随机消费")
	target.damage_rules.clear()
	target.attributes.set_base_value(&"dodge", 156.25)
	_check(_calc().hit_rate == 0.5 and not _calc().is_dodged, "随机等于命中率时命中")
	_check(_calc({}, {"random_values": {"calDamage": 0.5001}}).is_dodged, "随机大于命中率才闪避")
	target.attributes.set_base_value(&"dodge", 0.0)
	attacker.attributes.set_base_value(&"critical", 78.125)
	_check(not _calc().is_crit, "随机等于暴击率时不暴击")
	attacker.damage_rules.set_source(&"buff", {"criticalRatio": 1.0})
	_check(_calc().crit_rate == 1.5 and _calc().is_crit, "核心暴击率截断后Buff概率不再次截断")
	attacker.attributes.set_level(2)
	attacker.attributes.set_base_value(&"critical", 50.0)
	target.attributes.set_base_value(&"toughness", 20.0)
	attacker.damage_rules.clear()
	_check(is_equal_approx(_calc().crit_rate, 50.0 / 156.25 - 20.0 / 281.25), "暴击韧性分别使用对方和自身等级分母")
	attacker.attributes.set_level(1)

func _verify_growth_and_exclusive() -> void:
	_reset()
	var config := {"skillDefault": 1.0, "skillAdd": 0.25, "skillAddLevelMax": 2, "skillCountAdd": [1, 3, 7]}
	_check(_calc(config, {"skill_level": 5}).calculated_damage == 127.0, "技能成长封顶且附伤越界用末项")
	attacker.damage_rules.set_source(&"skill", {"skillAdd": 1.0})
	_check(_calc(config, {"skill_level": 5}).calculated_damage == 147.0, "技能Buff额外等级在成长封顶后追加")
	_check(config.skillDefault == 1.0 and config.skillCountAdd == [1, 3, 7], "定义资源不会被释放实例等级写回")
	attacker.damage_rules.clear()
	_check(_calc({"skillCountAdd": "1;3;7"}, {"skill_level": 3}).calculated_damage == 87.0, "原版分号附伤数组按等级索引")
	_check(_calc({"skillCountAdd": "1,3,7"}, {"skill_level": 3}).calculated_damage == 87.0, "兼容原版逗号附伤配置")
	_check(_calc({}, {"original_skill_id": 1001030}).calculated_damage == 96.0, "显式来源编号读取原版参数而不改变业务技能ID")
	_check(_calc({"source_skill_id": 1105101, "custom": {"damageRatio": 0.425}}).calculated_damage == 88.0, "防御转附伤在物理截断前进入")
	attacker.damage_rules.set_source(&"exclusive", {"exclusiveDamage": 7.0})
	_check(_calc().calculated_damage == 87.0, "角色专属附伤入口")
	attacker.damage_rules.clear()
	var result := _calc({}, {"ability_id": &"sunwukong_attack3", "damage_multiplier": 1.2})
	_check(result.calculated_damage == 96.0, "时间轴已含第三段倍率，不重复乘算")
#endregion
#region 后置顺序、护盾、生命结果和GAS效果
func _verify_post_order() -> void:
	_reset()
	target.damage_rules.set_source(&"rate", {"dmgRate": 50.0})
	var info := _calc({"realDamagePercent": 0.5, "realDamageRatio": 1.0})
	_check(is_equal_approx(info.normal_damage, 26.64) and info.true_damage == 50.0, "增减伤向下保留三位，真实伤害不吃普通减伤")
	target.damage_rules.clear()
	target.damage_rules.grant_shield(&"first", 20.0)
	target.damage_rules.grant_shield(&"second", 30.0)
	info = _calc({"realDamagePercent": 0.5, "realDamageRatio": 1.0})
	_check(target.damage_rules.get_shield_total() == 50.0, "只计算不消耗护盾")
	_check(_apply(info) == 51.0 and info.shield_absorbed == 40.0 and target.damage_rules.get_shield_total() == 10.0, "两层盾吸收普通40，真实50穿盾，普通原版补1")
	_check(_apply(info) == 51.0 and target.damage_rules.get_shield_total() == 10.0, "同一个DamageInfo不能再次扣血或耗盾")
	_reset()
	target.damage_rules.grant_shield(&"shield", 20.0)
	target.damage_rules.set_source(&"block", {"subDamage": 0.5, "block_omnidirectional": true})
	attacker.damage_rules.set_source(&"extra", {"fixedAdditional": 0.5})
	info = _calc()
	_check(_apply(info) == 45.0 and info.shield_absorbed == 20.0 and info.is_blocked, "原顺序：80先盾减20，再格挡半伤，再追加50%")
	var stages: Array = info.trace.map(func(row: Dictionary) -> StringName: return row.stage)
	_check(stages.find(&"damage_buffs") < stages.find(&"shields") and stages.find(&"shields") < stages.find(&"block") and stages.find(&"block") < stages.find(&"fixed_additional") and stages.find(&"last_damage") < stages.find(&"immunity"), "原版关键后置回调顺序")
	_reset()
	target.damage_rules.set_source(&"immune", {"immune": true})
	info = _calc({"realDamagePercent": 1.0})
	_check(_apply(info) == 0.0 and info.is_immune, "免疫同时阻止普通和真实分量")
	_reset()
	target.damage_rules.hooks[&"last_damage"] = [func(packet: DamageInfo, _who: Node, _ctx: Dictionary) -> void: packet.normal_damage = 13.0]
	info = _calc()
	_check(_apply(info) == 13.0, "角色最终伤害回调可以改写分量")
	_reset()
	var health := target.attributes.get_vital(&"health") as HealthVital
	health.set_current_value(5.0)
	info = _calc()
	_check(_apply(info) == 5.0 and info.calculated_damage == 80.0 and info.final_damage == 80.0 and info.hp_after == 0.0, "过量伤害80与真实扣血5分开")
	## 本轮结束，后续使用左侧独立木桩。
	target = demo.dummies[0]
	_check(target.is_alive() and target.damage_rules.get_shield_total() == 0.0, "同类怪物生命和护盾不会污染")

func _verify_effect_resources() -> void:
	_reset()
	var effect := GE_ApplyDamage.new()
	effect.damage_strategy = strategy
	effect.damage_multiplier = 0.5
	for i in range(2):
		var ctx := {"random_values": RANDOM, "damage_multiplier": 1.0}
		effect.apply(target, attacker, ctx)
		_check(ctx.damage_info.actual_hp_loss == 40.0, "连续复用Effect资源倍率不累乘")
	_check(effect.damage_multiplier == 0.5 and effect.damage_strategy == strategy, "共享伤害Effect保持只读")
	var shield := GE_BattleDamageRules.new()
	shield.shield_amount = 100.0
	shield.rules = {"fixedDodgeRate": 0.2}
	shield.apply(target, attacker, {"source_id": &"buff.a"})
	_check(target.damage_rules.get_shield_total() == 100.0, "护盾接入GAS Effect")
	shield.remove(target, attacker, {"source_id": &"buff.a"})
	_check(target.damage_rules.get_shield_total() == 0.0 and target.damage_rules.get_number(&"fixedDodgeRate") == 0.0, "Buff结束同时撤销盾与概率规则")
	TagManager.add_tag(target, &"state.invulnerable")
	var ctx := {"random_values": RANDOM}
	effect.apply(target, attacker, ctx)
	_check(ctx.has("damage_info") and ctx.damage_info.is_immune and ctx.damage_info.actual_hp_loss == 0.0, "GAS免疫标签保留伤害结果而不是丢掉事件")
	TagManager.remove_tag(target, &"state.invulnerable")

func _verify_status_and_hooks() -> void:
	_reset()
	var data := load("res://data/damage/normal_shield.tres") as GameplayStatusData
	target.statuses.apply_status(data, attacker)
	_check(target.damage_rules.get_shield_total() == 100.0, "普通护盾由真实GAS状态施加")
	var info := _calc()
	_check(_apply(info) == 1.0 and info.shield_absorbed == 80.0 and target.damage_rules.get_shield_total() == 20.0, "原版盾后补1：满盾普通攻击仍扣1生命")
	target.statuses.advance_simulation(8.0)
	_check(target.damage_rules.get_shield_total() == 0.0 and not target.statuses.has_status(&"normal_shield"), "战斗时间到期撤销残余盾")
	_reset()
	target.damage_rules.grant_shield(&"shield", 100.0)
	info = _calc({"realDamagePercent": 1.0})
	_check(_apply(info) == 100.0 and info.normal_damage == 0.0 and info.shield_absorbed == 0.0 and target.damage_rules.get_shield_total() == 100.0, "纯真实伤害清普通补1并完整绕盾")
	_reset()
	attacker.damage_rules.set_source(&"rate", {"atkDmgRate": 50.0})
	_check(_calc().calculated_damage == 120.0, "攻击增伤超过目标减伤时采用负差值分支")
	_reset()
	attacker.damage_rules.set_source(&"steal", {"lifeStealRatio": 0.5})
	var health := attacker.attributes.get_vital(&"health") as HealthVital
	health.set_current_value(100.0)
	target.damage_rules.grant_shield(&"shield", 100.0)
	info = _calc()
	_apply(info)
	_check(health.current_value == 140.0 and info.actual_hp_loss == 1.0, "原版吸血先于盾：按80伤害吸40，不按实际扣血1")
	_reset()
	attacker.damage_rules.set_source(&"combo", {"passive_id": 1303110, "hitCombo": 25})
	_check(_calc().calculated_damage == 100.0, "连击被动25次封顶25%核心加成")
	_reset()
	attacker.damage_rules.set_source(&"fifth", {"passive_id": 1301010})
	_check(_calc({}, {"ability_id": &"sunwukong_attack5"}).is_crit, "原版悟空第五段被动强制暴击")
	_reset()
	attacker.damage_rules.set_source(&"back", {"passive_id": 1303010})
	_check(_calc({}, {"back_hit": true}).calculated_damage == 96.0, "原版背击被动普通伤害增20%")
	_reset()
	attacker.damage_rules.set_source(&"buff", {"skillAdd": 1.0})
	info = _calc({"skillType": 3, "skillDefault": 1.0, "skillAdd": 0.5, "skillAddLevelMax": 0, "realDamagePercent": 0.5})
	_check(info.normal_damage == 40.0 and info.true_damage == 75.0, "技能类型3普通排除Buff等级，真实分支仍加入")
	_reset()
	info = _calc({"skillDefault": 0.0, "realDamagePercent": 1.0})
	_check(info.true_damage == 0.0, "真实分支零倍率不会被普通分支补成1")
	_reset()
	var listener := func(event: Dictionary) -> void:
		if event.entity == target:
			event.damage_info.final_damage *= 0.5
	CoreSystem.event_bus.subscribe("damage_received", listener)
	info = _calc({"realDamagePercent": 0.5})
	_apply(info)
	CoreSystem.event_bus.unsubscribe("damage_received", listener)
	_check(info.normal_damage == 20.0 and info.true_damage == 25.0 and info.actual_hp_loss == 45.0, "旧Core监听器只改final_damage也同步两个分量")
	_reset()
	var rng_before: Dictionary = demo.session.random.snapshot()
	_calc()
	_check(demo.session.random.snapshot() == rng_before, "固定随机注入不消费场次随机流")
	var random_info := DamageCalculator.calculate_damage(target, attacker, {"ability_id": &"sunwukong_attack1"})
	_check(random_info.trace.filter(func(row: Dictionary) -> bool: return row.stage == &"random").size() == 3, "普通攻击恰好按顺序消费命中、暴击、浮动三个随机")
#endregion
#region 真正输入时间轴和整数反馈
func _verify_real_attack() -> void:
	## 新建整套预置场景，避免单位测试木桩死亡影响验收。
	demo.session.clear_battle()
	demo.queue_free()
	await get_tree().process_frame
	demo = load("res://tests/fixtures/original_damage_demo.tscn").instantiate()
	demo.enable_player_controls = false
	add_child(demo)
	demo.session.set_physics_process(false)
	for i in range(40):
		demo.session.advance_physics(1.0 / 60.0)
	demo.place_near()
	var victim: BattleEntity2D = demo.dummies[1]
	_check(demo.player.request_attack(), "完整场景可以发起原版普攻")
	for i in range(8):
		demo.session.advance_physics(1.0 / 60.0)
	_check(victim.attributes.get_vital_value(&"health") == 420.0 and demo.total_hits == 1, "预置场景朝右命中右木桩一次80伤害")
	_check(victim.feedback.get_node("DamageLabel").text == "−80" and victim.feedback.get_node("HealthLabel").text == "420 / 500", "伤害与生命标签只显示整数")
	_check(not demo.info.text.contains(".25"), "EXP分母面板显示整数但计算保持精度")
	for sample in range(1, 8):
		for tick in range(30):
			demo.session.advance_physics(1.0 / 60.0)
		demo.set_sample(sample)
		var before: float = victim.attributes.get_vital_value(&"health")
		_check(demo.player.request_attack(), "八种样例均通过同一技能输入入口")
		for tick in range(8):
			demo.session.advance_physics(1.0 / 60.0)
		var actual: float = before - victim.attributes.get_vital_value(&"health")
		var expected := [80, 160, 40, 87, 90, 30, 0, 0]
		_check(is_equal_approx(actual, float(expected[sample])), "完整时间轴样例扣血：%s" % demo.SAMPLES[sample])
		if sample == 6:
			_check(victim.feedback.get_node("DamageLabel").text == "闪避" and not victim.feedback.hit_effect.visible, "闪避显示反馈且不播放受击效果")
		if sample == 7:
			_check(victim.feedback.get_node("DamageLabel").text == "免疫" and not victim.feedback.hit_effect.visible, "免疫显示反馈且不播放受击效果")
	for tick in range(30):
		demo.session.advance_physics(1.0 / 60.0)
	demo.set_sample(0)
	var activation := {"skill_level": 3, "skill_config": {"skillAdd": 0.25}}
	_check(demo.player.try_activate_skill(&"sunwukong_attack1", activation), "GAS释放上下文接收本次技能等级")
	activation.skill_level = 9
	for tick in range(8):
		demo.session.advance_physics(1.0 / 60.0)
	_check(victim.attributes.get_vital_value(&"health") == 380.0, "本次等级3得到120伤害，修改原上下文不改变释放快照")
#endregion
