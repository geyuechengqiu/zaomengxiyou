extends RefCounted
class_name BattleClock
#region 时间状态
## 仅由 BattleSession._physics_process 调用，UI 使用自身的未缩放时间。
var elapsed: float = 0.0
var physics_tick: int = 0
var paused: bool = false
var time_scale: float = 1.0
var hit_stop_remaining: float = 0.0
var last_delta: float = 0.0
#endregion
#region 公共接口
func set_time_scale(value: float) -> bool:
	if not is_finite(value) or value < 0.0:
		return false
	time_scale = value
	return true

## 重叠停顿取较长的剩余时长；按未缩放秒计时，菜单暂停冻结停顿倒计时。
func request_hit_stop(seconds: float) -> void:
	if is_finite(seconds) and seconds > 0.0:
		hit_stop_remaining = maxf(hit_stop_remaining, seconds)

func advance(unscaled_delta: float, tree_paused: bool = false, combat_delta_filter: Callable = Callable()) -> float:
	last_delta = 0.0
	if not is_finite(unscaled_delta) or unscaled_delta <= 0.0 or paused or tree_paused:
		return 0.0
	physics_tick += 1
	var stopped := minf(hit_stop_remaining, unscaled_delta)
	hit_stop_remaining = maxf(0.0, hit_stop_remaining - stopped)
	last_delta = (unscaled_delta - stopped) * time_scale
	if combat_delta_filter.is_valid(): last_delta = combat_delta_filter.call(last_delta)
	elapsed += last_delta
	return last_delta
#endregion
