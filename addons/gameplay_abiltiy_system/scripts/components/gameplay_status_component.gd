extends Node
class_name GameplayStatusComponent
#region 实例容器与统一时钟
# 同ID可拥有多个独立实例；所有生命周期操作使用实例身份，避免旧回调移除新Buff。
var _active_statuses: Array[GameplayStatusInstance] = []
var _event_bus: Node
var _clearing: bool = false
@export var externally_driven: bool = false
@export var filter_events_by_owner: bool = false
signal status_applied(status_id: StringName, instance: GameplayStatusInstance)
signal status_removed(status_id: StringName)
signal status_stacked(status_id: StringName, new_stacks: int)

func _enter_tree() -> void:
	_event_bus = CoreSystem.event_bus
	if not _event_bus.event_pushed.is_connected(_on_core_event_pushed):
		_event_bus.event_pushed.connect(_on_core_event_pushed)

func _exit_tree() -> void:
	if is_instance_valid(_event_bus) and _event_bus.event_pushed.is_connected(_on_core_event_pushed):
		_event_bus.event_pushed.disconnect(_on_core_event_pushed)
	_event_bus = null

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and not _active_statuses.is_empty():
		clear_statuses(&"exit")

func _process(delta: float) -> void:
	if not externally_driven:
		advance_simulation(delta)

func advance_simulation(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for instance in get_active_statuses():
		if _active_statuses.has(instance) and instance.update(delta):
			remove_instance(instance, &"expired")
#endregion
#region 施加、叠加及覆盖
func apply_status(data: GameplayStatusData, instigator: Node, stacks: int = 1, context: Dictionary = {}) -> GameplayStatusInstance:
	if not GameplayTriggerGuard.enter():
		return null
	var attributes := GameplayAbilitySystem.get_component_by_interface(get_parent(), &"GameplayVitalAttributeComponent") as GameplayAttributeComponent
	if attributes != null:
		attributes.begin_update()
	var instance := _apply_status_internal(data, instigator, stacks, context)
	if attributes != null:
		attributes.end_update()
	GameplayTriggerGuard.leave()
	return instance

func _apply_status_internal(data: GameplayStatusData, instigator: Node, stacks: int, context: Dictionary) -> GameplayStatusInstance:
	if data == null or _clearing or not is_finite(data.duration) or data.max_stacks < 1:
		return null
	if get_parent().has_method("can_receive_status") and not get_parent().can_receive_status(data):
		return null
	var key := data.stacking_group if not data.stacking_group.is_empty() else data.status_id
	var owner_source := StringName(context.get("status_owner_source", &""))
	var existing: GameplayStatusInstance
	if not key.is_empty():
		for candidate in _active_statuses:
			var candidate_key := candidate.status_data.stacking_group if not candidate.status_data.stacking_group.is_empty() else candidate.status_data.status_id
			if candidate_key == key and candidate.owner_source_id == owner_source:
				existing = candidate
				break
	if existing != null:
		if data.priority < existing.status_data.priority:
			return null
		if data.priority > existing.status_data.priority:
			remove_instance(existing, &"replaced")
		elif data.stacking_policy == null or not data.stacking_policy.allows_parallel_instances():
			var previous := existing.stacks
			if data.stacking_policy == null or data.stacking_policy.handle_stacking(existing, data, stacks, context):
				if existing.stacks != previous:
					status_stacked.emit(existing.status_data.status_id, existing.stacks)
				return existing
	# 配置也克隆：外部修改资源不会改变已施加Buff的持续时间和效果。
	var instance := GameplayStatusInstance.new(data.duplicate_deep(Resource.DEEP_DUPLICATE_ALL), self, instigator, clampi(stacks, 1, data.max_stacks))
	instance.owner_source_id = owner_source
	if data.duration != 0.0:
		_active_statuses.append(instance)
	instance.apply(context)
	if instance.removed:
		return null
	status_applied.emit(data.status_id, instance)
	CoreSystem.event_bus.push_event("status_applied", [{"entity": get_parent(), "status_id": data.status_id, "status_instance": instance}], true)
	return instance
#endregion
#region 移除、清理及查询
func remove_instance(instance: GameplayStatusInstance, reason: StringName = &"removed") -> void:
	if not _active_statuses.has(instance):
		return
	_active_statuses.erase(instance)
	instance.remove(reason)
	var id := instance.status_data.status_id
	status_removed.emit(id)
	CoreSystem.event_bus.push_event("status_removed", [{"entity": get_parent(), "status_id": id, "reason": reason}], true)

func remove_status(status_id: StringName) -> void:
	for instance in get_active_statuses():
		if instance.status_data.status_id == status_id:
			remove_instance(instance)

func clear_statuses(reason: StringName = &"cleared") -> void:
	if _clearing:
		return
	_clearing = true
	for instance in get_active_statuses():
		if reason != &"death" or instance.status_data.remove_on_death:
			remove_instance(instance, reason)
	_clearing = false

func remove_statuses_by_tags(tags: Array[StringName]) -> void:
	for instance in get_active_statuses():
		for tag in tags:
			if instance.status_data.tags.has(tag):
				remove_instance(instance, &"dispelled")
				break

func get_active_statuses() -> Array[GameplayStatusInstance]:
	return _active_statuses.duplicate()

func get_status(id: StringName) -> GameplayStatusInstance:
	for instance in _active_statuses:
		if instance.status_data.status_id == id:
			return instance
	return null

func has_status(id: StringName) -> bool:
	return get_status(id) != null

func get_random_status(is_debuff: bool = false, debuff_tag: String = "status.debuff") -> GameplayStatusInstance:
	var candidates: Array[GameplayStatusInstance] = []
	for instance in _active_statuses:
		if not is_debuff or instance.status_data.tags.has(StringName(debuff_tag)):
			candidates.append(instance)
	if candidates.is_empty():
		return null
	return candidates[get_parent().get_battle_random_int(0, candidates.size() - 1, &"combat")] if get_parent().has_method("get_battle_random_int") else candidates.pick_random()
#endregion
#region 安全事件快照
func handle_event(id: StringName, context: Dictionary) -> void:
	for instance in get_active_statuses():
		if _active_statuses.has(instance) and not instance.removed:
			instance.handle_event(id, context)

func _on_core_event_pushed(id: String, payload: Array) -> void:
	if _active_statuses.is_empty():
		return
	if payload.size() != 1 or not payload[0] is Dictionary:
		return
	if filter_events_by_owner and get_parent().has_method("accepts_status_event") and not get_parent().accepts_status_event(payload[0]):
		return
	handle_event(StringName(id), payload[0])
#endregion
