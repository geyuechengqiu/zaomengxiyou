extends RefCounted
class_name BattleMotionController2D
#region 独立速度、接触与跳跃预算
var body: CharacterBody2D
var grounded: bool = false
var on_wall: bool = false
var on_ceiling: bool = false
var just_landed: bool = false
var jumps_used: int = 0
var jump_count: int = 0
var landing_serial: int = 0
var jump_serial: int = 0
#endregion
#region 跳跃入口
func can_jump(maximum_jumps: int) -> bool:
	return maximum_jumps > 0 and (grounded or maxi(jumps_used, 1) < maximum_jumps)

func jump(profile: BattleActionProfile2D) -> bool:
	if not can_jump(profile.maximum_jumps):
		return false
	jumps_used = 1 if grounded else maxi(jumps_used, 1) + 1
	jump_count = jumps_used
	jump_serial += 1
	grounded = false
	just_landed = false
	body.velocity.y = profile.jump_velocity if jumps_used == 1 else profile.second_jump_velocity
	return true
#endregion
#region 战斗时间中的扫掠碰撞
func advance(delta: float, horizontal_speed: float, profile: BattleActionProfile2D) -> void:
	just_landed = false
	on_wall = false
	on_ceiling = false
	var count := maxi(1, int(ceil(delta / (1.0 / 60.0))))
	var step_delta := delta / count
	for tick in range(count):
		var was_grounded := grounded
		grounded = false
		body.velocity.x = horizontal_speed
		body.velocity.y = minf(body.velocity.y + profile.gravity * step_delta, profile.maximum_fall_speed)
		var remaining := body.velocity * step_delta
		for iteration in range(6):
			var collision := body.move_and_collide(remaining)
			if collision == null:
				break
			var normal := collision.get_normal()
			if normal.dot(Vector2.UP) >= cos(profile.maximum_floor_angle):
				grounded = true
			elif normal.dot(Vector2.DOWN) > 0.7:
				on_ceiling = true
			else:
				on_wall = true
			body.velocity = body.velocity.slide(normal)
			remaining = collision.get_remainder().slide(normal)
			if remaining.is_zero_approx():
				break
		# 只在已有支撑且没有上升时吸附；不能让正在跳跃的角色被拉回平台。
		if not grounded and was_grounded and body.velocity.y >= 0.0:
			var support := body.move_and_collide(Vector2.DOWN * profile.floor_snap_distance, true)
			if support != null and support.get_normal().dot(Vector2.UP) >= cos(profile.maximum_floor_angle):
				body.move_and_collide(support.get_travel())
				grounded = true
				body.velocity.y = 0.0
		if grounded and not was_grounded:
			just_landed = true
			landing_serial += 1
			jumps_used = 0
		elif not grounded and was_grounded:
			# 走下边缘消耗地面起跳额度，只保留一次空中跳跃。
			jumps_used = maxi(jumps_used, 1)
#endregion
