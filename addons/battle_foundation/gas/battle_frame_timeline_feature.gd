extends GameplayAbilityFeature
class_name BattleFrameTimelineFeature
#region 素材时间定义
@export var source_fps: float = 30.0
@export var duration_frames: int = 30
## 按 source_frame 非递减排序；同帧事件保留配置顺序。
@export var events: Array[BattleFrameEvent] = []
@export_group("Segmented Skill")
@export var attack_segments: Array[BattleAttackSegment] = []
@export var branch_windows: Array[BattleSkillBranch] = []
@export var motion_windows: Array[BattleSkillMotion] = []
## -1 自动使用首个攻击段作为前摇结束、最后一段作为后摇开始。
@export var recovery_start_frame: int = -1
@export var animation_action: StringName = &"attack_1"
@export var action_rules: Dictionary = {"move": false, "jump": false, "turn": false}
## 行为树技能保持原有提交方式；分段技能由此时间轴提交 GAS 消耗与冷却。
@export var commit_resources: bool = false
#endregion
#region GAS 生命周期
func _init() -> void:
	super("BattleFrameTimelineFeature")

func can_activate(ability: GameplayAbilityInstance, _context: Dictionary) -> bool:
	return not ability.is_active and is_configuration_valid()

func on_activate(ability: GameplayAbilityInstance, context: Dictionary) -> void:
	## 每次释放快照；事件/攻击段显式配置优先，不把实例等级写回定义。
	var damage_context := {}
	for key in ["skill_level", "buff_level", "skill_config", "original_skill_id", "secret_bonus", "dynamic_true_ratio", "damage_multiplier_modifier", "damage_strategy", "random_values", "is_item", "is_pvp", "is_qc", "cannot_dodge", "has_damage"]:
		if context.has(key):
			damage_context[key] = context[key]
	_set_data(ability, "damage_context", damage_context.duplicate(true))
	_set_data(ability, "elapsed", 0.0)
	_set_data(ability, "next_event", 0)
	var pending: Array[Dictionary] = []
	for marker in events:
		pending.append({"time": marker.source_frame / source_fps, "kind": "marker", "marker": marker, "order": pending.size()})
	for segment in attack_segments:
		pending.append({"time": segment.start_frame / source_fps, "kind": "sample", "segment": segment, "order": pending.size()})
		if segment.end_frame > segment.start_frame:
			pending.append({"time": segment.end_frame / source_fps, "kind": "close", "segment": segment, "order": pending.size()})
	for branch in branch_windows:
		pending.append({"time": branch.start_frame / source_fps, "kind": "branch", "order": pending.size()})
	if not attack_segments.is_empty():
		var recovery := recovery_start_frame
		if recovery < 0:
			recovery = 0
			for segment in attack_segments:
				recovery = maxi(recovery, segment.end_frame)
		pending.append({"time": recovery / source_fps, "kind": "recovery", "order": pending.size()})
	_set_data(ability, "pending", pending)
	## 帧 0 在首个逻辑 tick 触发，确保 GAS 完成激活再发送。

func update(ability: GameplayAbilityInstance, delta: float) -> void:
	if not ability.is_active or delta <= 0.0:
		return
	if uses_cast_timeline():
		_update_segments(ability, delta)
		return
	var serial := ability.activation_serial
	var elapsed: float = _get_data(ability, "elapsed", 0.0) + delta
	_set_data(ability, "elapsed", elapsed)
	var index: int = _get_data(ability, "next_event", 0)
	while index < events.size() and elapsed + 0.000000001 >= events[index].source_frame / source_fps:
		var marker := events[index]
		index += 1
		_set_data(ability, "next_event", index)
		_emit_marker(ability, marker)
		## 同步事件可能取消技能，取消后不再发送后续跨帧事件。
		if not ability.is_active or ability.activation_serial != serial:
			return
	if elapsed + 0.000000001 >= duration_frames / source_fps:
		ability.end_ability()

func on_completed(ability: GameplayAbilityInstance) -> void:
	_set_data(ability, "pending", [])
	var owner := ability.get_owner_entity()
	if is_instance_valid(owner) and owner.has_method("get_attack_instance"):
		var attack: BattleAttackInstance = owner.get_attack_instance()
		if attack != null and attack.active and attack.ability_id == ability.get_definition().ability_id:
			owner.finish_timeline_cast(attack, &"cancelled" if ability.completion_status == BTNode.Status.FAILURE else &"completed")
#endregion
#region 按时间排序重放跨帧攻击与事件
func _update_segments(ability: GameplayAbilityInstance, delta: float) -> void:
	var owner := ability.get_owner_entity() as BattleEntity2D
	if owner == null:
		return
	var cast := owner.get_attack_instance()
	if cast == null or not cast.active or cast.ability_id != ability.get_definition().ability_id:
		return
	if commit_resources and not cast.committed:
		var context: Dictionary = ability.get_blackboard_var("context", {})
		var cost := ability.get_feature("CostFeature") as CostFeature
		if cost != null and not cost.try_pay(ability, context):
			owner.cancel_skill(&"cost_failed")
			return
		if not _is_current(ability, owner, cast):
			return
		cast.committed = true
		var cooldown := ability.get_feature("CooldownFeature") as CooldownFeature
		if cooldown != null and not context.get("skip_cooldown", false):
			cooldown.start_cooldown(ability)
		owner.publish_battle_event(&"battle.skill.committed", {"attack_id": cast.attack_id, "ability_id": cast.ability_id})
		if not _is_current(ability, owner, cast):
			return
	var previous: float = _get_data(ability, "elapsed", 0.0)
	var until := minf(previous + delta, duration_frames / source_fps)
	var pending: Array = _get_data(ability, "pending", [])
	# 消费旧缓存的时间在上一 tick 末尾；不要把输入倒灌到更早的素材帧。
	cast.elapsed = previous
	owner.consume_skill_branch(cast)
	while _is_current(ability, owner, cast) and not pending.is_empty():
		pending.sort_custom(func(a: Dictionary, b: Dictionary): return a.time < b.time if not is_equal_approx(a.time, b.time) else a.order < b.order)
		if float(pending[0].time) > until + 0.000000001:
			break
		var item: Dictionary = pending.pop_front()
		owner.advance_timeline_motion(cast, float(item.time))
		_set_data(ability, "elapsed", cast.elapsed)
		if not _is_current(ability, owner, cast):
			return
		match String(item.kind):
			"marker":
				_emit_marker(ability, item.marker)
			"sample":
				var segment: BattleAttackSegment = item.segment
				if cast.phase == &"startup":
					cast.phase = &"active"
				var context := segment.get_payload()
				context["timeline_sample"] = true
				context["sample_time"] = item.time
				context["window_start"] = segment.start_frame / source_fps
				context["window_end"] = segment.end_frame / source_fps
				_emit_context(ability, &"battle.attack.impact", context, float(item.time) * source_fps)
				var interval := segment.hit_interval if segment.hit_interval > 0.0 else 1.0 / source_fps
				var next := float(item.time) + interval
				if next + 0.000000001 < segment.end_frame / source_fps:
					pending.append({"time": next, "kind": "sample", "segment": segment, "order": item.order})
			"close":
				var segment: BattleAttackSegment = item.segment
				cast.windows.erase(segment.hit_index)
				owner.publish_battle_event(&"battle.attack.window_closed", {"attack_id": cast.attack_id, "hit_index": segment.hit_index, "skill_time": item.time})
			"branch":
				owner.consume_skill_branch(cast)
			"recovery":
				cast.phase = &"recovery"
				owner.publish_battle_event(&"battle.skill.recovery", {"attack_id": cast.attack_id, "skill_time": item.time})
	if not _is_current(ability, owner, cast):
		return
	owner.advance_timeline_motion(cast, until)
	if not _is_current(ability, owner, cast):
		return
	_set_data(ability, "elapsed", until)
	if until + 0.000000001 >= duration_frames / source_fps:
		ability.end_ability()

func _is_current(ability: GameplayAbilityInstance, owner: BattleEntity2D, cast: BattleAttackInstance) -> bool:
	return ability.is_active and cast.active and owner.get_attack_instance() == cast and owner.is_alive() and not owner.session.is_simulation_blocked()

func uses_cast_timeline() -> bool:
	return not attack_segments.is_empty() or not branch_windows.is_empty() or not motion_windows.is_empty() or commit_resources
#endregion
#region 校验与帧事件
func is_configuration_valid() -> bool:
	if not is_finite(source_fps) or source_fps <= 0.0 or duration_frames <= 0:
		return false
	var previous := -1
	for marker in events:
		if marker == null or marker.source_frame < previous or marker.source_frame < 0:
			return false
		if marker.source_frame > duration_frames or marker.event_id.is_empty():
			return false
		previous = marker.source_frame
	var indices: Dictionary = {}
	var ids: Dictionary = {}
	for segment in attack_segments:
		if segment == null or not segment.is_valid(duration_frames) or indices.has(segment.hit_index) or ids.has(segment.segment_id):
			return false
		indices[segment.hit_index] = true
		ids[segment.segment_id] = true
		for marker in events:
			if marker.event_id == &"battle.attack.impact" and int(marker.payload.get("hit_index", 1)) == segment.hit_index:
				return false
	for branch in branch_windows:
		if branch == null or not branch.is_valid(duration_frames):
			return false
	for window in motion_windows:
		if window == null or not window.is_valid(duration_frames):
			return false
	if recovery_start_frame < -1 or recovery_start_frame > duration_frames:
		return false
	if recovery_start_frame >= 0:
		for segment in attack_segments:
			if recovery_start_frame < segment.end_frame:
				return false
	return true

func _emit_marker(ability: GameplayAbilityInstance, marker: BattleFrameEvent) -> void:
	_emit_context(ability, marker.event_id, marker.payload.duplicate(true), marker.source_frame)

func _emit_context(ability: GameplayAbilityInstance, event_id: StringName, payload: Dictionary, source_frame: float) -> void:
	var owner := ability.get_owner_entity()
	payload.merge(_get_data(ability, "damage_context", {}), false)
	payload["ability_id"] = ability.get_definition().ability_id
	payload["source_frame"] = int(source_frame) if is_equal_approx(source_frame, round(source_frame)) else source_frame
	payload["source_fps"] = source_fps
	payload["skill_time"] = source_frame / source_fps
	if is_instance_valid(owner) and owner.has_method("get_attack_instance"):
		var attack: BattleAttackInstance = owner.get_attack_instance()
		if attack != null and attack.ability_id == ability.get_definition().ability_id:
			payload["attack_id"] = attack.attack_id
	if is_instance_valid(owner) and owner.has_method("publish_battle_event"):
		owner.publish_battle_event(event_id, payload)
	else:
		payload["entity"] = owner
		CoreSystem.event_bus.push_event(String(event_id), [payload], true)
#endregion
