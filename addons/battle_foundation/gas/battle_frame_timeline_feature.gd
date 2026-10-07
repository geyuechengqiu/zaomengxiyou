extends GameplayAbilityFeature
class_name BattleFrameTimelineFeature
#region 素材时间定义
@export var source_fps: float = 30.0
@export var duration_frames: int = 30
## 按 source_frame 非递减排序；同帧事件保留配置顺序。
@export var events: Array[BattleFrameEvent] = []
#endregion
#region GAS 生命周期
func _init() -> void:
	super("BattleFrameTimelineFeature")

func can_activate(ability: GameplayAbilityInstance, _context: Dictionary) -> bool:
	return not ability.is_active and is_configuration_valid()

func on_activate(ability: GameplayAbilityInstance, _context: Dictionary) -> void:
	_set_data(ability, "elapsed", 0.0)
	_set_data(ability, "next_event", 0)
	## 帧 0 在首个逻辑 tick 触发，确保 GAS 完成激活再发送。

func update(ability: GameplayAbilityInstance, delta: float) -> void:
	if not ability.is_active or delta <= 0.0:
		return
	var elapsed: float = _get_data(ability, "elapsed", 0.0) + delta
	_set_data(ability, "elapsed", elapsed)
	var index: int = _get_data(ability, "next_event", 0)
	while index < events.size() and elapsed + 0.000000001 >= events[index].source_frame / source_fps:
		var marker := events[index]
		index += 1
		_set_data(ability, "next_event", index)
		_emit_marker(ability, marker)
		## 同步事件可能取消技能，取消后不再发送后续跨帧事件。
		if not ability.is_active:
			return
	if elapsed + 0.000000001 >= duration_frames / source_fps:
		ability.end_ability()
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
	return true

func _emit_marker(ability: GameplayAbilityInstance, marker: BattleFrameEvent) -> void:
	var owner := ability.get_owner_entity()
	var payload := marker.payload.duplicate(true)
	payload["ability_id"] = ability.get_definition().ability_id
	payload["source_frame"] = marker.source_frame
	payload["source_fps"] = source_fps
	payload["skill_time"] = marker.source_frame / source_fps
	if is_instance_valid(owner) and owner.has_method("get_attack_instance"):
		var attack: BattleAttackInstance = owner.get_attack_instance()
		if attack != null and attack.ability_id == ability.get_definition().ability_id:
			payload["attack_id"] = attack.attack_id
	if is_instance_valid(owner) and owner.has_method("publish_battle_event"):
		owner.publish_battle_event(marker.event_id, payload)
	else:
		payload["entity"] = owner
		CoreSystem.event_bus.push_event(String(marker.event_id), [payload], true)
#endregion
