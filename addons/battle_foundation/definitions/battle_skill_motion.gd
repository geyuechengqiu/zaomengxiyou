extends Resource
class_name BattleSkillMotion
#region 时间轴位移定义
@export var start_frame: int = 0
@export var end_frame: int = 4
## 世界像素/秒；X 按起手朝向镜像，经运动控制器碰撞扫掠。
@export var velocity: Vector2 = Vector2.ZERO

func is_valid(duration_frames: int) -> bool:
	return start_frame >= 0 and end_frame > start_frame and end_frame <= duration_frames and velocity.is_finite()
#endregion
