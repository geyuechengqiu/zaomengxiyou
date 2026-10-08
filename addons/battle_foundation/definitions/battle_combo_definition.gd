extends Resource
class_name BattleComboDefinition
#region 连击配置
@export var steps: Array[BattleAttackStep2D] = []
#endregion
#region 定义校验
func is_valid() -> bool:
	if steps.is_empty():
		return false
	for step in steps:
		if step == null or step.ability_id.is_empty() or step.action.is_empty() or step.duration_frames <= 0 or not is_finite(step.source_fps) or step.source_fps <= 0.0 or not step.is_turn_window_valid():
			return false
	return true
#endregion
