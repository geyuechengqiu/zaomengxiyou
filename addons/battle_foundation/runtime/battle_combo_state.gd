extends Node
class_name BattleComboState
#region 实例独立连击状态
var definition: BattleComboDefinition
var index: int = -1
var queued_next: bool = false
var cast_serial: int = 0
var motion_facing: int = 1
var turn_used: bool = false
#endregion
#region 开始、预约与取消
func is_active() -> bool:
	return definition != null and index >= 0 and index < definition.steps.size()

func get_step() -> BattleAttackStep2D:
	return definition.steps[index] if is_active() else null

func begin(step_index: int, facing: int = 1) -> void:
	index = step_index
	motion_facing = 1 if facing >= 0 else -1
	turn_used = false
	queued_next = false
	cast_serial += 1

func queue_next() -> bool:
	if not is_active() or index + 1 >= definition.steps.size() or queued_next:
		return false
	queued_next = true
	return true

func cancel() -> void:
	index = -1
	queued_next = false
	turn_used = false
	motion_facing = 1
#endregion
