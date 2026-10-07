extends Resource
class_name BattleAttackStep2D
#region 连击段定义（共享只读）
@export var ability_id: StringName
@export var action: StringName
@export var duration_frames: int = 10
@export var source_fps: float = 30.0
@export var allow_jump_cancel: bool = true
@export var allow_turn: bool = false
@export var interrupt_priority: int = 30
@export var super_armor: bool = false
## 技能规定的位移与玩家行走权限分开，仍经运动控制器碰撞。
@export var root_motion_speed: float = 0.0
@export var root_motion_frames: int = 0
#endregion
#region 时间与权限接口
func get_duration() -> float:
	return duration_frames / source_fps

func get_rules() -> Dictionary:
	return {"move": false, "jump": allow_jump_cancel, "turn": allow_turn, "interrupt_priority": interrupt_priority, "super_armor": super_armor}
#endregion
