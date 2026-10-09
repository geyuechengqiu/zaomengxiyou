extends RefCounted
class_name BattleAttackInstance
#region 一次施放的攻击状态
var attack_id: StringName
var ability_id: StringName
var attacker_id: StringName
var faction_id: StringName
var attacker: WeakRef
var elapsed: float = 0.0
var active: bool = true
var facing: int = 1
## 位移起手朝向独立于当前打击朝向，转身不能反转已施放的位移。
var motion_facing: int = 1
var phase: StringName = &"startup"
var committed: bool = false
var aim_degrees: float = 0.0
var hit_count: int = 0
## 原版addXPTotal属于本次释放，不能写回共用技能资源。
var rage_awarded: float = 0.0
var timeline: BattleFrameTimelineFeature
var buffered_operations: Dictionary = {}
var owned_objects: Array[WeakRef] = []
## hit_index -> 窗口上下文；每个窗口均独立去重，第四段仍允许两次命中。
var windows: Dictionary = {}
var hit_targets: Dictionary = {}

func initialize(owner_entity: BattleEntity2D, skill_id: StringName, serial: int) -> void:
	attacker = weakref(owner_entity)
	attacker_id = owner_entity.entity_id
	faction_id = owner_entity.faction_id
	ability_id = skill_id
	attack_id = StringName("%s/attack/%d" % [attacker_id, serial])
	facing = owner_entity.animation.get_facing()
	motion_facing = facing
	timeline = owner_entity.abilities.get_ability_instance(skill_id).get_feature("BattleFrameTimelineFeature") as BattleFrameTimelineFeature

func open_window(context: Dictionary, duration: float) -> bool:
	var index := int(context.get("hit_index", 1))
	if not active or index < 1 or windows.has(index):
		return false
	var data := context.duplicate(true)
	data["window_end"] = float(context.skill_time) + maxf(0.0, duration)
	windows[index] = data
	return true

func register_hit(index: int, target_id: StringName, context: Dictionary = {}) -> bool:
	var key := "%d/%s" % [index, target_id]
	var record: Dictionary = hit_targets.get(key, {"count": 0, "next_hit_time": 0.0})
	var maximum := int(context.get("maximum_hits", 1))
	var interval := float(context.get("hit_interval", 0.0))
	var sample_time := float(context.get("sample_time", elapsed))
	if not active or int(record.count) >= maximum or (int(record.count) > 0 and (interval <= 0.0 or sample_time + 0.000000001 < float(record.next_hit_time))):
		return false
	record.count += 1
	record.next_hit_time = sample_time + interval
	hit_targets[key] = record
	hit_count += 1
	return true

func next_hit_deadline(index: int, after: float, maximum: int, fallback: float) -> float:
	var next := fallback
	var prefix := "%d/" % index
	for key: String in hit_targets:
		if not key.begins_with(prefix): continue
		var record: Dictionary = hit_targets[key]
		if int(record.count) < maximum and float(record.next_hit_time) > after + 0.000000001:
			next = minf(next, float(record.next_hit_time))
	return next

func close() -> void:
	active = false
	phase = &"ended"
	windows.clear()
	buffered_operations.clear()
	var objects := owned_objects.duplicate()
	owned_objects.clear()
	for reference in objects:
		var object: Variant = reference.get_ref()
		if is_instance_valid(object):
			object.release_cast(attack_id)
#endregion
#region 位移、派生缓存与拥有的场景对象
func get_motion_delta(delta: float) -> Vector2:
	return get_motion_between(elapsed, elapsed + delta)

func get_motion_between(from_time: float, to_time: float) -> Vector2:
	var movement := Vector2.ZERO
	if not active or timeline == null:
		return movement
	for window in timeline.motion_windows:
		var overlap := maxf(0.0, minf(to_time, window.end_frame / timeline.source_fps) - maxf(from_time, window.start_frame / timeline.source_fps))
		movement += window.velocity * overlap
	movement.x *= motion_facing
	return movement

func buffer_operation(operation: StringName) -> bool:
	if not active or timeline == null:
		return false
	var expiry := -1.0
	for branch in timeline.branch_windows:
		if branch.operation == operation and elapsed + 0.000000001 >= (branch.start_frame - branch.buffer_frames) / timeline.source_fps and elapsed < branch.end_frame / timeline.source_fps:
			expiry = maxf(expiry, minf(branch.end_frame / timeline.source_fps, elapsed + branch.buffer_frames / timeline.source_fps))
	if expiry < 0.0:
		return false
	buffered_operations[operation] = expiry
	return true

func get_ready_branch() -> BattleSkillBranch:
	if not active or timeline == null:
		return null
	var selected: BattleSkillBranch
	for branch in timeline.branch_windows:
		if not buffered_operations.has(branch.operation):
			continue
		if float(buffered_operations[branch.operation]) + 0.000000001 < elapsed:
			continue
		if elapsed + 0.000000001 >= branch.start_frame / timeline.source_fps and elapsed < branch.end_frame / timeline.source_fps:
			if selected == null or branch.priority > selected.priority:
				selected = branch
	return selected

func track_object(object: BattleTimelineObject2D) -> void:
	for reference in owned_objects:
		if reference.get_ref() == object:
			return
	owned_objects.append(weakref(object))

func advance_objects(delta: float) -> void:
	for reference in owned_objects.duplicate():
		var object: Variant = reference.get_ref()
		if is_instance_valid(object) and object.cast_id == attack_id:
			var object_delta := minf(delta, maxf(0.0, elapsed - float(object.last_skill_time)))
			object.last_skill_time = elapsed
			object.advance_object(object_delta)
#endregion
