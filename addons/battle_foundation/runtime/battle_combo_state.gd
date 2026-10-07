extends RefCounted
class_name BattleComboState
#region 实例独立连击状态
var definition: BattleComboDefinition
var index: int = -1
var queued_next: bool = false
var cast_serial: int = 0
var hit_targets: Dictionary = {}
#endregion
#region 开始、预约与取消
func is_active() -> bool:
	return definition != null and index >= 0 and index < definition.steps.size()

func get_step() -> BattleAttackStep2D:
	return definition.steps[index] if is_active() else null

func begin(step_index: int) -> void:
	index = step_index
	queued_next = false
	cast_serial += 1
	hit_targets.clear()

func queue_next() -> bool:
	if not is_active() or index + 1 >= definition.steps.size() or queued_next:
		return false
	queued_next = true
	return true

func cancel() -> void:
	index = -1
	queued_next = false
	hit_targets.clear()

func register_hit(hit_index: int, entity_id: StringName) -> bool:
	var key := "%d/%s" % [hit_index, entity_id]
	if hit_targets.has(key):
		return false
	hit_targets[key] = true
	return true
#endregion
