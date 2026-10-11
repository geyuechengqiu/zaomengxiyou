extends DamageLogicStrategy
class_name BattleOriginalDamageStrategy
#region 只读原版配置
@export_file("*.json") var levels_path: String = ""
@export_file("*.json") var skills_path: String = ""
@export_file("*.json") var mapping_path: String = ""
var _levels: Dictionary = {}
var _skills: Dictionary = {}
var _mapping: Dictionary = {}
const RESISTS := ["", "lightResist", "darkResist", "waterResist", "fireResist", "woodResist", "soilResist", "windResist", "rayResist"]

func _load_tables() -> void:
	if _levels.is_empty() and not levels_path.is_empty():
		_levels = JSON.parse_string(FileAccess.get_file_as_string(levels_path))
	if _skills.is_empty() and not skills_path.is_empty():
		_skills = JSON.parse_string(FileAccess.get_file_as_string(skills_path))
	if _mapping.is_empty() and not mapping_path.is_empty():
		_mapping = JSON.parse_string(FileAccess.get_file_as_string(mapping_path))

func get_level_parameters(level: int) -> Dictionary:
	_load_tables()
	return _levels.get(str(level), {}).duplicate(true)

func get_skill_parameters(id: StringName) -> Dictionary:
	_load_tables()
	return _skills.get(str(int(_mapping.get(String(id), -1))), {}).duplicate(true)
#endregion
#region 原版通用核心：命中→暴击→减法防御→抗性
func calculate(target: Node, instigator: Node, context: Dictionary) -> float:
	return calculate_result(target, instigator, context).calculated_damage

func resolves_invulnerability() -> bool:
	return true

func calculate_result(target: Node, instigator: Node, context: Dictionary) -> DamageInfo:
	var info := DamageInfo.new(instigator, context.get("source_node"))
	info.single_use = true
	var ctx := context.duplicate(true)
	var ar := _rules(instigator)
	var tr := _rules(target)
	_hook(&"before_calculate", ar, tr, info, target, ctx)
	var attacker := _attributes(instigator)
	var defender := _attributes(target)
	var ap := get_level_parameters(int(attacker.level))
	var dp := get_level_parameters(int(defender.level))
	if ap.is_empty() or dp.is_empty():
		info.record(&"invalid_level", {"attacker_level": attacker.level, "target_level": defender.level})
		return info
	var skill := _skill(ctx)
	var level := maxi(1, int(ctx.get("skill_level", ar.skill_levels.get(ctx.get("ability_id", &""), 1)))) + int(ctx.get("buff_level", 0))
	ctx["lifesteal_skill_multiplier"] = float(skill.get("skillDefault", 1.0)) + float(skill.get("skillAdd", 0.0)) * (level - 1)
	var cheat: Dictionary = ctx.get("secret_bonus", {})
	var hit := float(attacker.hit) + float(attacker.base.hit) * float(cheat.get("hit", 0.0))
	var diff := hit / float(dp.hitAttribute) - float(defender.dodge) / float(ap.dodgeAttribute)
	info.hit_rate = clampf(clampf(1.0 + diff / (absf(diff) + 1.0) - tr.get_number(&"fixedDodgeRate"), 0.0, 1.0) + ar.get_number(&"hitPercent"), 0.0, 1.0)
	var hit_roll := _random(&"calDamage", instigator, ctx, info)
	if bool(ctx.get("is_item", false)) or tr.has_flag(&"cannot_dodge") or bool(ctx.get("cannot_dodge", false)):
		info.hit_rate = 1.0
	info.is_dodged = info.hit_rate == 0.0 or hit_roll > info.hit_rate
	info.record(&"hit", {"rate": info.hit_rate, "roll": hit_roll})
	if info.is_dodged:
		return info
	var secret_crit := (float(attacker.base.critical) + 2.0 * float(ap.criticalMax)) * float(cheat.get("critical", 0.0))
	info.crit_rate = clampf((float(attacker.critical) + secret_crit) / float(dp.criticalMax) - float(defender.toughness) / float(ap.toughnessMax) + ar.get_number(&"addBaoJiRate") + tr.get_number(&"hurtBaoJiRate"), 0.0, 1.0) + ar.get_number(&"criticalRatio") + ar.get_number(&"mazeCriticalRatio")
	var passive := int(ar.get_number(&"passive_id"))
	var lost_bonus := _lost_hp_bonus(ar, attacker)
	if passive == 1301110 and info.crit_rate < 1.0:
		info.crit_rate += float(lost_bonus.critical)
	if int(skill.get("source_skill_id", 0)) == 1001050 and passive == 1301010:
		info.crit_rate = 1.0
	_hook(&"crit_rate", ar, tr, info, target, ctx)
	info.is_crit = _random(&"baojiRatio", instigator, ctx, info) < info.crit_rate
	var secret_lucky := (float(attacker.base.lucky) + 2.0 * float(ap.luckyMax)) * float(cheat.get("lucky", 0.0))
	var lucky := (float(attacker.lucky) + secret_lucky) * (1.0 + ar.get_number(&"luckyRatio"))
	info.crit_multiplier = 1.0 + clampf(1.0 + lucky / float(dp.luckyMax) - float(defender.guardian) / float(ap.guardianMax), 0.0, 2.0)
	var multiplier := _skill_multiplier(skill, level, int(attacker.level), ar, false, ctx)
	var fixed := _fixed_bonus(skill, level) + float(ctx.get("fixed_damage", 0.0))
	var effective_atk := float(attacker.atk) + float(attacker.base.atk) * float(cheat.get("atk", 0.0))
	var jitter := 0.95 + 0.10000000000000009 * _random(&"calPhysicalDamage", instigator, ctx, info)
	if bool(ctx.get("test_damage_random_1", false)):
		jitter = 1.0
	var exclusive := ar.get_number(&"exclusiveDamage") + float(ctx.get("exclusive_damage", 0.0))
	var source_id := int(skill.get("source_skill_id", 0))
	if source_id in [1105101, 3105408]:
		exclusive += (float(attacker.phyDef) + float(attacker.base.phyDef) * float(cheat.get("phyDef", 0.0))) * float(skill.get("custom", {}).get("damageRatio", 0.425))
	elif source_id in [1105060, 1105061, 1105062] and bool(ctx.get("secret_15061001", false)):
		exclusive += float(attacker.phyDef) * 0.8
	info.base_damage = int(maxf(effective_atk - float(defender.phyDef), 1.0) * jitter * multiplier + fixed + exclusive)
	info.normal_damage = info.base_damage
	info.record(&"physical", {"attack": effective_atk, "defense": defender.phyDef, "jitter": jitter, "multiplier": multiplier, "fixed": fixed, "exclusive": exclusive})
	if info.is_crit:
		info.normal_damage = int(info.normal_damage * info.crit_multiplier)
	info.record(&"critical", {"rate": info.crit_rate, "multiplier": info.crit_multiplier, "critical": info.is_crit})
	if passive == 1303110:
		var combo := ar.get_number(&"hitCombo")
		info.normal_damage *= 1.0 + (0.25 if combo >= 25.0 else clampf((sqrt(maxf(0.0, combo * 25.0)) - (25.0 - combo) / 10.0) / 100.0, 0.0, 0.25))
	var assassinate := 0.0
	if passive == 1303210 and bool(ctx.get("has_damage", true)) and float(defender.hp_ratio) <= (0.2 if tr.has_flag(&"boss") or tr.has_flag(&"role") else 0.5) and float(defender.hp) > 0.0:
		if _random(&"ansha", instigator, ctx, info) < info.normal_damage / float(defender.hp) * 0.35:
			assassinate = float(defender.hp)
	var element := int(skill.get("type", 0))
	var resistance := float(defender.get(RESISTS[element], 0.0)) if element > 0 and element < RESISTS.size() else 0.0
	info.normal_damage = int(info.normal_damage * (100.0 / (resistance + 100.0) if resistance > 0.0 else 1.0 - resistance / 100.0))
	info.record(&"resistance", {"element": element, "resistance": resistance})
	info.normal_damage *= 1.0 + float(skill.get("skillDefaultRatio", 0.0))
	if passive == 1301110:
		info.normal_damage *= 1.0 + float(lost_bonus.damage)
	info.normal_damage = maxf(1.0, info.normal_damage)
	_hook(&"after_core", ar, tr, info, target, ctx)
	var true_percent := float(skill.get("realDamagePercent", 0.0)) + float(ctx.get("dynamic_true_ratio", 0.0)) + ar.get_number(&"realDamagePercent")
	info.normal_damage *= 1.0 - true_percent
	if true_percent != 0.0:
		info.true_damage = true_percent * (float(attacker.atk) * _skill_multiplier(skill, level, int(attacker.level), ar, true, ctx) + fixed) * (info.crit_multiplier if info.is_crit else 1.0) * float(skill.get("realDamageRatio", 1.0)) * (1.0 + float(skill.get("skillDefaultRatio", 0.0)))
	info.record(&"true_split", {"percent": true_percent})
	if bool(ctx.get("back_hit", _is_back_hit(instigator, target))) and passive == 1303010:
		info.normal_damage *= 1.2
	ctx["assassinate_damage"] = assassinate if bool(ctx.get("back_hit", _is_back_hit(instigator, target))) else 0.0
	if float(ctx.assassinate_damage) > 0.0:
		info.normal_damage = float(ctx.assassinate_damage)
	_hook(&"back_hit", ar, tr, info, target, ctx)
	diff = tr.get_number(&"dmgRate") - ar.get_number(&"atkDmgRate")
	var rate := 1.0 - (diff / (diff + 100.0) if diff > 0.0 else diff / 100.0)
	rate = floorf(rate * 1000.0) / 1000.0
	info.normal_damage *= rate
	info.true_damage *= maxf(rate, 1.0)
	info.record(&"damage_rate", {"multiplier": rate})
	info.final_damage = maxf(0.0, info.normal_damage + info.true_damage)
	info.calculated_damage = info.final_damage
	info.application_resolver = _resolve_application.bind(weakref(instigator) if instigator != null else null, ctx, true_percent)
	return info
#endregion
#region Vital应用：保持原版后置顺序，计算接口不消耗护盾
func _resolve_application(info: DamageInfo, target: Node, notify_received: Callable, attacker_ref: WeakRef, ctx: Dictionary, true_percent: float) -> void:
	var attacker: Node = attacker_ref.get_ref() if attacker_ref != null else null
	var ar := _rules(attacker)
	var tr := _rules(target)
	## GAS 同步事件修改普通和真实分量，发生在原版伤害Buff位置。
	var before := info.final_damage
	notify_received.call()
	if not is_equal_approx(before, info.final_damage) and is_equal_approx(info.normal_damage + info.true_damage, before):
		var ratio := info.final_damage / before if before > 0.0 else 0.0
		info.normal_damage *= ratio
		info.true_damage *= ratio
	_hook(&"damage_buffs", ar, tr, info, target, ctx)
	## 原版吸血发生在盾前，使用这一阶段数值；不是实际扣血。
	info.lifesteal_basis = maxf(0.0, info.normal_damage + info.true_damage)
	var life_steal := ar.get_number(&"lifeStealRatio") * info.lifesteal_basis
	var life_cap := ar.get_number_or(&"lifeStealCap", INF)
	if is_finite(life_cap):
		life_steal = minf(life_steal, maxf(0.0, life_cap * float(ctx.get("lifesteal_skill_multiplier", 1.0))))
	info.lifesteal_requested = life_steal
	if life_steal > 0.0 and is_instance_valid(attacker):
		var comp := GameplayAbilitySystem.get_component_by_interface(attacker, "GameplayVitalAttributeComponent")
		if comp != null and comp.get_vital(&"health") is HealthVital:
			var health := comp.get_vital(&"health") as HealthVital
			var hp := health.current_value
			health.heal(life_steal)
			info.lifesteal_actual = maxf(0.0, health.current_value - hp)
	info.record(&"lifesteal", {"requested_heal": life_steal})
	_hook(&"lifesteal", ar, tr, info, target, ctx)
	info.normal_damage += ar.get_number(&"extraDamage")
	_hook(&"extra_damage", ar, tr, info, target, ctx)
	info.normal_damage *= ar.get_number_or(&"hpDamageMultiplier", 1.0) * tr.get_number_or(&"hpHurtMultiplier", 1.0)
	_hook(&"hp_ratio", ar, tr, info, target, ctx)
	_hook(&"damage_transfer", ar, tr, info, target, ctx)
	if tr.has_flag(&"no_damage"):
		info.normal_damage = 0.0
		info.true_damage = 0.0
		info.is_immune = true
	_hook(&"no_damage", ar, tr, info, target, ctx)
	info.shield_absorbed = tr.absorb_normal(maxf(0.0, info.normal_damage))
	info.normal_damage -= info.shield_absorbed
	_hook(&"shields", ar, tr, info, target, ctx)
	var block := tr.get_number_or(&"subDamage", 0.0)
	if block > 0.0 and (tr.has_flag(&"block_omnidirectional") or _is_front_hit(attacker, target, ctx)):
		info.normal_damage *= block
		info.true_damage *= block
		info.is_blocked = true
	_hook(&"block", ar, tr, info, target, ctx)
	var additional := ar.get_number(&"fixedAdditional") + ar.get_number(&"fixedAdditional2")
	if additional > 0.0:
		info.normal_damage *= 1.0 + additional
		info.true_damage *= 1.0 + additional
	_hook(&"fixed_additional", ar, tr, info, target, ctx)
	if float(ctx.get("assassinate_damage", 0.0)) > 0.0:
		info.normal_damage = float(ctx.assassinate_damage)
	elif int(ar.get_number(&"passive_id")) == 1303210 and bool(ctx.get("back_hit", _is_back_hit(attacker, target))):
		if _random(&"double_damage", attacker, ctx, info) <= 0.15:
			info.normal_damage *= 2.0
			info.true_damage *= 2.0
	_hook(&"special_double", ar, tr, info, target, ctx)
	var cap := tr.get_number_or(&"bossDamageCap", INF)
	if is_finite(cap):
		info.normal_damage = minf(info.normal_damage, cap)
	_hook(&"boss_cap", ar, tr, info, target, ctx)
	## DamageControl.as:1533 的第二次补1在盾后；保留原版穿盾1点的行为。
	if bool(ctx.get("has_damage", true)) and not tr.has_flag(&"no_damage") and info.normal_damage < 1.0:
		info.normal_damage = 1.0
	info.record(&"post_shield_minimum")
	_hook(&"sharing", ar, tr, info, target, ctx)
	_hook(&"last_damage", ar, tr, info, target, ctx)
	if tr.has_flag(&"damageToHealing"):
		var health: HealthVital = GameplayAbilitySystem.get_component_by_interface(target, "GameplayVitalAttributeComponent").get_vital(&"health")
		health.heal(ceilf(maxf(0.0, info.normal_damage) * tr.get_number_or(&"healingRatio", 1.0)))
		info.normal_damage = 0.0
	_hook(&"damage_to_healing", ar, tr, info, target, ctx)
	## 纯真实分支去掉原版中途被重新补到1的普通尾数。
	if true_percent >= 1.0 and info.normal_damage <= 1.0:
		info.normal_damage = 0.0
	if tr.has_flag(&"immune") or TagManager.has_tag(target, &"state.invulnerable"):
		info.normal_damage = 0.0
		info.true_damage = 0.0
		info.is_immune = true
	_hook(&"immunity", ar, tr, info, target, ctx)
	_hook(&"attacker_final", ar, tr, info, target, ctx)
	info.final_damage = maxf(0.0, info.normal_damage + info.true_damage)
	info.record(&"resolved", {"shield_absorbed": info.shield_absorbed})
#endregion
#region 配置、随机与回调工具
func _skill(ctx: Dictionary) -> Dictionary:
	var id := StringName(ctx.get("sub_skill_id", &""))
	if id.is_empty():
		id = StringName(ctx.get("ability_id", &""))
	var result := get_skill_parameters(id)
	if ctx.has("original_skill_id"):
		result = _skills.get(str(int(ctx.original_skill_id)), {}).duplicate(true)
	result.merge(ctx.get("skill_config", {}), true)
	## 已有时间轴倍率是该攻击段的基础倍率，避免第三/五段被乘两次。
	if ctx.has("damage_multiplier"):
		result["skillDefault"] = float(ctx.damage_multiplier)
	result["skillDefault"] = float(result.get("skillDefault", 1.0)) * float(ctx.get("damage_multiplier_modifier", 1.0))
	return result

func _skill_multiplier(skill: Dictionary, level: int, actor_level: int, rules: BattleDamageRules, real: bool, ctx: Dictionary) -> float:
	var growth := level - 1
	var cap := int(skill.get("skillAddLevelMax", 0))
	var special := int(skill.get("skillType", 0)) == 3
	if special:
		growth = actor_level - 1
		if bool(ctx.get("is_pvp", false)) or bool(ctx.get("is_qc", false)):
			growth = 0
	if cap > 0 or (special and not real):
		growth = mini(growth, cap)
	var result := float(skill.get("skillDefault", 1.0)) + float(skill.get("skillAdd", 0.0)) * (growth + (rules.get_number(&"skillAdd") if real or not special else 0.0))
	return 1.0 if result == 0.0 and not real else result

func _fixed_bonus(skill: Dictionary, level: int) -> float:
	var values: Variant = skill.get("skillCountAdd", [])
	if values is String:
		values = values.replace(",", ";").split(";")
	if values is Array or values is PackedStringArray:
		return float(values[clampi(level - 1, 0, values.size() - 1)]) if not values.is_empty() else 0.0
	return float(values)

func _attributes(entity: Node) -> Dictionary:
	var result := {"base": {}, "level": 1, "hp_ratio": 1.0, "hp": 0.0}
	var comp := GameplayAbilitySystem.get_component_by_interface(entity, "GameplayVitalAttributeComponent") if is_instance_valid(entity) else null
	for key in ["atk", "phyDef", "hit", "dodge", "critical", "toughness", "lucky", "guardian"] + RESISTS.slice(1):
		var value: float = comp.get_value(StringName(key)) if comp != null and comp.has_attribute(StringName(key)) else 0.0
		result[key] = roundf(value) if key in ["atk", "phyDef"] else value
		result.base[key] = comp.get_layer_value(StringName(key), false) if comp is BattleAttributeComponent else value
	if comp != null:
		result.level = comp.current_level if comp is BattleAttributeComponent else (int(comp.get_value(&"level")) if comp.has_attribute(&"level") else 1)
		var health: GameplayVital = comp.get_vital(&"health")
		if health != null:
			result.hp_ratio = health.get_percent()
			result.hp = health.current_value
	return result

func _rules(entity: Node) -> BattleDamageRules:
	return entity.get_damage_rules() if is_instance_valid(entity) and entity.has_method("get_damage_rules") else BattleDamageRules.new()

func _hook(stage: StringName, ar: BattleDamageRules, tr: BattleDamageRules, info: DamageInfo, target: Node, ctx: Dictionary) -> void:
	ar.run_hook(stage, info, target, ctx)
	if ar != tr:
		tr.run_hook(stage, info, target, ctx)
	info.record(stage)

func _random(reason: StringName, attacker: Node, ctx: Dictionary, info: DamageInfo) -> float:
	var fixed: Dictionary = ctx.get("random_values", {})
	var value: float
	if fixed.has(reason):
		value = float(fixed[reason])
	elif is_instance_valid(attacker) and attacker.has_method("get_battle_random_float"):
		value = attacker.get_battle_random_float(&"combat")
	else:
		## 脱离会话必须提供固定输入，避免悄悄使用全局随机。
		push_error("Original damage requires a BattleRandom host or fixed random_values")
		value = 0.5
	info.record(&"random", {"reason": reason, "value": value})
	return value

func _is_back_hit(attacker: Node, target: Node) -> bool:
	return attacker is BattleEntity2D and target is BattleEntity2D and attacker.animation != null and target.animation != null and attacker.animation.get_facing() == target.animation.get_facing() and (target.global_position.x - attacker.global_position.x) * attacker.animation.get_facing() > 0.0

func _is_front_hit(attacker: Node, target: Node, ctx: Dictionary) -> bool:
	if not attacker is BattleEntity2D or not target is BattleEntity2D or target.animation == null:
		return bool(ctx.get("front_hit", false))
	return (attacker.global_position.x - target.global_position.x) * target.animation.get_facing() > 0.0

func _lost_hp_bonus(rules: BattleDamageRules, attacker: Dictionary) -> Dictionary:
	var lost := rules.get_number(&"totalLoastHpPercent")
	var custom: Dictionary = _skills.get("1301110", {}).get("custom", {})
	var k := rules.get_number_or(&"passive_k", float(custom.get("k", 111.0)))
	var y := rules.get_number_or(&"passive_y", float(custom.get("y", 111.0)))
	var z := rules.get_number_or(&"passive_z", float(custom.get("z", 111.0)))
	var limit := rules.get_number_or(&"passive_MAX", float(custom.get("MAX", 0.35)))
	var critical := minf(maxf(k * lost / (y + lost) + z, z), limit)
	var n := rules.get_number_or(&"passive_n", float(custom.get("n", 111.0)))
	var damage: float = minf(lost / rules.get_number_or(&"passive_c", float(custom.get("c", 111.0))) * n, n) * float(attacker.hp_ratio) / (float(attacker.hp_ratio) + rules.get_number_or(&"passive_a", float(custom.get("a", 111.0)))) + rules.get_number_or(&"passive_b", float(custom.get("b", 111.0)))
	return {"critical": critical, "damage": damage}
#endregion
