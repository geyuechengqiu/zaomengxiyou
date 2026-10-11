extends BattleAIController2D
class_name BattleBossController2D
#region 预置Boss组件；仍向Core动作状态机提交技能意图
@export var boss_profile: BattleBossProfile
@export var objects_path: NodePath = ^"../BossObjects"
var elapsed: float = 0.0
var phase_id: StringName = &"normal"
var phase_transitions: int = 0
var summon_total: int = 0
var summon_deaths: int = 0
var summons: Dictionary = {}
var group_deadlines: Dictionary = {}
var selected_skills: Array[StringName] = []
var consumed_phases: Dictionary = {}
var threshold_reached: Dictionary = {}
var pending_rule: BattleBossSkillRule
var lead_remaining: float = 0.0
var request_serial: int = 0
var objects: BattleBossObjectPool2D
var _stopped: bool = false
var _transition: BattleBossPhase
var _transition_cast: StringName
var _before_skill_time: float = 0.0
var _tick_delta: float = 0.0

func bind(owner_actor: BattleEntity2D) -> void:
	super.bind(owner_actor)
	assert(boss_profile != null and boss_profile.is_valid(), "Boss需要有效专属行为配置")
	for rule in boss_profile.skills: assert(actor.abilities.has_ability(rule.ability_id), "Boss技能未登记：" + String(rule.ability_id))
	for phase in boss_profile.phases: assert(phase.entry_ability_id.is_empty() or actor.abilities.has_ability(phase.entry_ability_id), "阶段进入技能未登记")
	objects = get_node_or_null(objects_path) as BattleBossObjectPool2D
	assert(objects != null, "Boss时间轴对象池必须在场景中预置")
	objects.bind(actor)
	actor.attributes.vital_depleted.connect(_on_depleted)
	actor.attributes.snapshot_changed.connect(_on_snapshot)
	CoreSystem.event_bus.event_pushed.connect(_on_boss_event)
	actor.publish_battle_event(&"battle.boss.registered", {"boss_name": boss_profile.display_name, "health_bar_count": boss_profile.health_bar_count})

func _exit_tree() -> void:
	cleanup_boss()
#endregion
#region 独立决策与阈值锁存；全程仅消费combat delta
func advance_simulation(delta: float) -> void:
	if _stopped or actor == null or delta <= 0 or actor.session.is_simulation_blocked(): return
	_tick_delta = delta
	_before_skill_time = actor.attack_instance.elapsed if actor.attack_instance != null and actor.attack_instance.active else 0.0
	if not actor.is_alive():
		cleanup_boss()
		return
	_update_summons()
	if not enabled:
		_cancel_lead(&"disabled")
		_stop_movement()
		set_state(&"DISABLED")
		return
	elapsed += delta
	_detect_thresholds()
	_step_delta = delta
	retreat_remaining = maxf(0.0, retreat_remaining-delta)
	if _transition != null and (actor.attack_instance == null or not actor.attack_instance.active): _finish_phase()
	var attacking := actor.attack_instance != null and actor.attack_instance.active
	if attacking or not actor.action_state.get_permission(&"move", actor.action_profile):
		if not attacking: _cancel_lead(&"controlled")
		_stop_movement()
		set_state(&"PHASE" if _transition != null else (&"CASTING" if attacking else &"CONTROLLED"))
		return
	if elapsed < boss_profile.intro_seconds:
		_stop_movement()
		set_state(&"INTRO")
		return
	if _begin_phase(): return
	if pending_rule != null:
		_stop_movement()
		lead_remaining = maxf(0.0, lead_remaining-delta)
		if lead_remaining <= 0.0000001:
			lead_remaining = 0
			_cast_pending()
		return
	decision_remaining -= delta
	if decision_remaining > 0 and is_instance_valid(target) and target.is_alive(): return
	decision_remaining = profile.decision_interval
	target = profile.target_selector.select_target(actor, profile, home)
	if not is_instance_valid(target):
		_submit_movement(movement_to(home.x) if absf(actor.global_position.x-home.x) > profile.home_tolerance else 0.0)
		set_state(&"RETURN")
		return
	var offset := target.global_position-actor.global_position
	if absf(actor.global_position.x-home.x) > profile.leash_radius:
		_submit_movement(movement_to(home.x))
		set_state(&"RETURN")
		return
	if retreat_remaining > 0 and absf(offset.x) < profile.maximum_retreat_distance:
		_submit_movement(-signf(offset.x))
		set_state(&"RETREAT")
		return
	var rule := _choose_skill(offset)
	if rule != null and actor.motion.grounded and actor.action_state.can_attack(true):
		_submit_movement(0)
		if offset.x != 0: actor.animation.set_facing(int(signf(offset.x)))
		pending_rule = rule
		lead_remaining = rule.announcement_lead_seconds
		request_serial += 1
		actor.publish_battle_event(&"battle.boss.skill_selected", _request_payload(rule))
		if rule.announcement != null or lead_remaining > 0:
			actor.publish_battle_event(&"battle.boss.announced", _request_payload(rule))
		set_state(&"ANNOUNCING")
		if lead_remaining <= 0: _cast_pending()
		return
	_submit_movement(signf(offset.x) if absf(offset.x) > profile.attack_range else 0.0)
	set_state(&"CHASE" if absf(offset.x) > profile.attack_range else &"COOLDOWN")
	if profile.jump_obstacles and actor.motion.grounded and actor.motion.on_wall: _submit(&"jump")

func _choose_skill(offset: Vector2) -> BattleBossSkillRule:
	var candidates: Array[BattleBossSkillRule] = []
	var priority := -2147483648
	var ratio := actor.attributes.get_vital_value(&"health")/maxf(1, actor.attributes.get_value(&"hpMax"))
	for rule in boss_profile.skills:
		if absf(offset.x) > rule.attack_range or absf(offset.x) < rule.minimum_range or absf(offset.y) > rule.vertical_range: continue
		if ratio < rule.minimum_health_ratio or ratio > rule.maximum_health_ratio or (not rule.phase_ids.is_empty() and not rule.phase_ids.has(phase_id)): continue
		if elapsed+0.0000001 < float(group_deadlines.get(rule.cooldown_group, 0)) or not _conditions_met(rule.required_conditions) or (rule.requires_no_summons and not summons.is_empty()): continue
		if not actor.abilities.can_activate_ability(rule.ability_id, {}): continue
		if rule.priority > priority:
			priority = rule.priority
			candidates.clear()
		if rule.priority == priority: candidates.append(rule)
	if candidates.is_empty(): return null
	var total := 0.0
	for rule in candidates: total += rule.weight
	var roll := actor.session.random.random_float(&"boss_ai")*total
	for rule in candidates:
		roll -= rule.weight
		if roll <= 0: return rule
	return candidates[-1]

func _request_payload(rule: BattleBossSkillRule) -> Dictionary:
	return {"request_id": request_serial, "ability_id": rule.ability_id, "announcement": rule.announcement, "lead_seconds": rule.announcement_lead_seconds, "warning_rect": rule.warning_rect, "facing": actor.animation.get_facing(), "origin": actor.global_position}

func _cast_pending() -> void:
	var rule := pending_rule
	if rule == null: return
	if _submit(&"ai_skill", {&"ai_skill": rule.ability_id}) != BattleActionLeafState2D.OperationResult.ACCEPTED:
		_cancel_lead(&"activation_failed")
		return
	pending_rule = null
	group_deadlines[rule.cooldown_group] = elapsed+rule.group_cooldown
	successful_casts += 1
	selected_skills.append(rule.ability_id)
	actor.publish_battle_event(&"battle.boss.action_started", {"ability_id": rule.ability_id, "request_id": request_serial, "attack_id": actor.attack_instance.attack_id})
	set_state(&"CASTING")

func _cancel_lead(reason: StringName) -> void:
	if pending_rule == null: return
	pending_rule = null
	lead_remaining = 0
	actor.publish_battle_event(&"battle.boss.announcement_cancelled", {"request_id": request_serial, "reason": reason})

func _conditions_met(ids: Array) -> bool:
	if ids.is_empty(): return true
	var level := actor.session.level_instance
	if level == null: return false
	for id in ids:
		if not level.conditions.get(id, false): return false
	return true

func _begin_phase() -> bool:
	for phase in boss_profile.phases:
		if consumed_phases.has(phase.phase_id) or not threshold_reached.has(phase.phase_id) or not _conditions_met(phase.required_conditions): continue
		_cancel_lead(&"phase_change")
		_stop_movement()
		if not phase.entry_ability_id.is_empty() and _submit(&"ai_skill", {&"ai_skill": phase.entry_ability_id}) != BattleActionLeafState2D.OperationResult.ACCEPTED: return false
		consumed_phases[phase.phase_id] = true
		phase_id = phase.phase_id
		phase_transitions += 1
		_transition = phase
		_transition_cast = actor.attack_instance.attack_id if not phase.entry_ability_id.is_empty() else &""
		if not phase.entry_ability_id.is_empty() and phase.invulnerable_during_entry: actor.damage_rules.set_source(&"boss_phase", {&"immune": true})
		actor.publish_battle_event(&"battle.boss.phase_changed", {"phase_id": phase_id, "display_name": phase.display_name, "transition_count": phase_transitions})
		if not phase.scene_event.is_empty(): actor.publish_battle_event(phase.scene_event, {"phase_id": phase_id})
		if phase.entry_ability_id.is_empty(): _finish_phase()
		return true
	return false

func _on_snapshot(_snapshot: Dictionary) -> void:
	if not _stopped: _detect_thresholds()

func _detect_thresholds() -> void:
	var ratio := actor.attributes.get_vital_value(&"health")/maxf(1, actor.attributes.get_value(&"hpMax"))
	if ratio <= 0: return
	for phase in boss_profile.phases:
		if ratio <= phase.health_ratio: threshold_reached[phase.phase_id] = true

func _finish_phase() -> void:
	actor.damage_rules.remove_source(&"boss_phase")
	_transition = null
	_transition_cast = &""
	actor.publish_battle_event(&"battle.boss.phase_finished", {"phase_id": phase_id})
#endregion
#region 时间轴对象与召唤生命周期
func advance_post_simulation(delta: float) -> void:
	if _stopped: return
	objects.advance_objects(delta, _before_skill_time, actor.session.clock.physics_tick)

func summon_monsters(ids: Array, offset: Vector2 = Vector2.ZERO) -> int:
	if _stopped or not actor.is_alive(): return 0
	_update_summons()
	var created := 0
	for id in ids:
		if summons.size() >= boss_profile.maximum_summons: break
		var monster := actor.session.spawn_entity_2d("monsters", StringName(id), actor.global_position+Vector2(offset.x*actor.animation.get_facing(), offset.y), actor.faction_id, true)
		if monster == null: continue
		monster.set_meta(&"summoner_id", actor.entity_id)
		summons[monster.entity_id] = weakref(monster)
		summon_total += 1
		created += 1
		actor.publish_battle_event(&"battle.boss.summoned", {"summon_id": monster.entity_id, "alive_count": summons.size(), "total_count": summon_total})
	return created

func _update_summons() -> void:
	for id in summons.keys():
		var monster := summons[id].get_ref() as BattleEntity2D
		if not is_instance_valid(monster) or monster.is_queued_for_deletion() or not monster.is_alive():
			# 回收会销毁动作状态机，不能用is_alive()把存活回收伪造成死亡。
			if is_instance_valid(monster) and monster.attributes.get_vital_value(&"health") <= 0: summon_deaths += 1
			summons.erase(id)
			actor.publish_battle_event(&"battle.boss.summon_removed", {"summon_id": id, "alive_count": summons.size(), "death_count": summon_deaths})
	if not boss_profile.completion_condition.is_empty() and actor.session.level_instance != null:
		actor.session.level_instance.set_condition(boss_profile.completion_condition, not actor.is_alive() and summons.is_empty())

func _on_boss_event(id: String, payload: Array) -> void:
	if _stopped or payload.size() != 1 or not payload[0] is Dictionary: return
	var data: Dictionary = payload[0]
	if data.get("battle_id") != actor.session.battle_id: return
	if id == "battle.entity_despawned" and summons.has(data.get("target_entity_id")):
		var summon_id: StringName = data.target_entity_id
		var monster := summons[summon_id].get_ref() as BattleEntity2D
		if is_instance_valid(monster) and monster.attributes.get_vital_value(&"health") <= 0: summon_deaths += 1
		summons.erase(summon_id)
		actor.publish_battle_event(&"battle.boss.summon_removed", {"summon_id": summon_id, "alive_count": summons.size(), "death_count": summon_deaths})
	elif id == "battle.entity.killed" and summons.has(data.get("target_entity_id")): _update_summons()
	if data.get("source_entity_id") != actor.entity_id: return
	if id == "battle.attack.finished":
		if data.reason == &"completed" and actor.attack_instance.timeline != null:
			var until := actor.attack_instance.timeline.duration_frames/actor.attack_instance.timeline.source_fps
			objects.advance_objects(minf(_tick_delta, maxf(0, until-_before_skill_time)), _before_skill_time, actor.session.clock.physics_tick, data.attack_id)
			if _stopped: return
		objects.release_attack(data.attack_id, data.reason != &"completed")
		if data.attack_id == _transition_cast: _finish_phase()
		if data.reason == &"completed": retreat_remaining = lerpf(profile.retreat_minimum, profile.retreat_maximum, actor.session.random.random_float(&"boss_ai"))
		else: actor.publish_battle_event(&"battle.boss.announcement_cancelled", {"request_id": request_serial, "reason": data.reason})
	elif id in ["battle.boss.objects", "battle.boss.summon"]:
		var cast := actor.attack_instance
		if cast == null or not cast.active or data.get("attack_id") != cast.attack_id or not actor.is_alive(): return
		if id == "battle.boss.objects": objects.spawn_objects(data, cast)
		else: summon_monsters(data.get("monster_ids", []), data.get("spawn_offset", Vector2.ZERO))

func _on_depleted(id: StringName) -> void:
	if id == &"health": cleanup_boss()

func cleanup_boss() -> void:
	if _stopped or actor == null: return
	_stopped = true
	_cancel_lead(&"owner_removed")
	if CoreSystem.event_bus.event_pushed.is_connected(_on_boss_event): CoreSystem.event_bus.event_pushed.disconnect(_on_boss_event)
	if actor.attributes.vital_depleted.is_connected(_on_depleted): actor.attributes.vital_depleted.disconnect(_on_depleted)
	if actor.attributes.snapshot_changed.is_connected(_on_snapshot): actor.attributes.snapshot_changed.disconnect(_on_snapshot)
	actor.damage_rules.remove_source(&"boss_phase")
	if is_instance_valid(objects): objects.clear_objects()
	_update_summons()
	for id in summons.keys(): actor.session.despawn_entity(id)
	summons.clear()
	_update_summons()
	set_state(&"DEAD" if not actor.is_alive() else &"STOPPED")
#endregion
