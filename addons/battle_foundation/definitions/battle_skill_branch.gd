extends Resource
class_name BattleSkillBranch
#region 操作派生定义
@export var operation: StringName = &"attack"
@export var target_ability_id: StringName = &"sunwukong_attack1"
@export var start_frame: int = 18
@export var end_frame: int = 24
@export var buffer_frames: int = 6
@export var priority: int = 0

func is_valid(duration_frames: int) -> bool:
	return not operation.is_empty() and not target_ability_id.is_empty() and start_frame >= 0 and end_frame > start_frame and end_frame <= duration_frames and buffer_frames >= 0
#endregion
