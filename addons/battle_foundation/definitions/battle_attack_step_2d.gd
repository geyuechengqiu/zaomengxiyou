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
## 半开原素材帧窗；-1关闭。每次施放仅接受一次新按下的反方向意图。
@export var turn_window_start_frame: int = -1
@export var turn_window_end_frame: int = -1
#endregion
#region 时间与权限接口
func is_turn_window_valid() -> bool:
	return (turn_window_start_frame == -1 and turn_window_end_frame == -1) or (turn_window_start_frame >= 0 and turn_window_end_frame > turn_window_start_frame and turn_window_end_frame <= duration_frames)

func contains_turn_time(time: float) -> bool:
	return turn_window_start_frame >= 0 and time + 0.000000001 >= turn_window_start_frame / source_fps and time + 0.000000001 < turn_window_end_frame / source_fps

func get_duration() -> float:
	return duration_frames / source_fps

func get_rules() -> Dictionary:
	return {"move": false, "jump": allow_jump_cancel, "turn": allow_turn, "interrupt_priority": interrupt_priority, "super_armor": super_armor}
#endregion
