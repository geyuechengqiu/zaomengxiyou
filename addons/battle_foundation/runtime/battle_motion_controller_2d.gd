extends Node
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
var impulse_speed: float = 0.0
var impulse_remaining: float = 0.0
var reaction_gravity: float = -1.0
## 当前战斗区域的水平限制只属于此运动实例，由关卡启停。
var horizontal_bounds_active: bool = false
var horizontal_bounds: Vector2
@export var body_shape_path: NodePath = ^"../CollisionShape2D"
#endregion
#region 区域边界；在扫掠前裁剪位移，保持竖向运动和场景碰撞
func set_horizontal_bounds(left: float, right: float) -> void:
	var limits := Vector2(left, right)
	var shape_node := get_node_or_null(body_shape_path) as CollisionShape2D
	if shape_node != null and shape_node.shape != null and not shape_node.disabled:
		var rect := shape_node.global_transform * shape_node.shape.get_rect()
		limits.x -= rect.position.x - body.global_position.x
		limits.y -= rect.end.x - body.global_position.x
	if limits.x > limits.y: limits = Vector2.ONE * (left + right) * 0.5
	horizontal_bounds = limits
	horizontal_bounds_active = true
	constrain_horizontal_position()

func clear_horizontal_bounds() -> void:
	horizontal_bounds_active = false

func constrain_horizontal_position() -> void:
	if not horizontal_bounds_active: return
	var position := body.global_position
	position.x = clampf(position.x, horizontal_bounds.x, horizontal_bounds.y)
	if position.x != body.global_position.x: body.global_position = position
	if (position.x <= horizontal_bounds.x and body.velocity.x < 0) or (position.x >= horizontal_bounds.y and body.velocity.x > 0): body.velocity.x = 0
	if (position.x <= horizontal_bounds.x and impulse_speed < 0) or (position.x >= horizontal_bounds.y and impulse_speed > 0):
		impulse_speed = 0
		impulse_remaining = 0

func _limit_displacement(displacement: Vector2) -> Vector2:
	if not horizontal_bounds_active: return displacement
	constrain_horizontal_position()
	var limited_x := clampf(body.global_position.x + displacement.x, horizontal_bounds.x, horizontal_bounds.y) - body.global_position.x
	if not is_equal_approx(limited_x, displacement.x):
		on_wall = true
		if body.velocity.x * displacement.x > 0: body.velocity.x = 0
		if impulse_speed * displacement.x > 0:
			impulse_speed = 0
			impulse_remaining = 0
	displacement.x = limited_x
	return displacement
#endregion
#region 跳跃入口
func can_jump(maximum_jumps: int) -> bool:
	return maximum_jumps > 0 and (grounded or jumps_used < maximum_jumps)

func jump(profile: BattleActionProfile2D) -> bool:
	if not can_jump(profile.maximum_jumps):
		return false
	jumps_used = 1 if grounded else jumps_used + 1
	jump_count = jumps_used
	jump_serial += 1
	grounded = false
	just_landed = false
	body.velocity.y = profile.jump_velocity if jumps_used == 1 else profile.second_jump_velocity
	return true
#endregion
#region 战斗时间中的扫掠碰撞
func sweep_skill_displacement(displacement: Vector2, profile: BattleActionProfile2D) -> void:
	if displacement.is_zero_approx():
		return
	var was_grounded := grounded
	if displacement.y < 0.0:
		grounded = false
	var remaining := displacement
	for iteration in range(6):
		remaining = _limit_displacement(remaining)
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
	if grounded:
		var support := body.move_and_collide(Vector2.DOWN * profile.floor_snap_distance, true)
		if support == null or support.get_normal().dot(Vector2.UP) < cos(profile.maximum_floor_angle):
			grounded = false
	if grounded and not was_grounded:
		just_landed = true
		landing_serial += 1
		jumps_used = 0
	# 走下平台或水平技能离开边缘不消耗跳跃，只在真正起跳时记次数。

func apply_impulse(horizontal: float, duration: float, launch: float, gravity: float = -1.0, reset_vertical: bool = false) -> void:
	impulse_speed = horizontal
	impulse_remaining = duration
	if launch > 0.0 or reset_vertical:
		body.velocity.y = -launch
		reaction_gravity = gravity
	if launch > 0.0:
		grounded = false
		jumps_used = maxi(jumps_used, 1)

func clear_impulse() -> void:
	impulse_speed = 0.0
	impulse_remaining = 0.0
	reaction_gravity = -1.0

func advance(delta: float, horizontal_speed: float, profile: BattleActionProfile2D, gravity_scale: float = 1.0) -> void:
	just_landed = false
	on_wall = false
	on_ceiling = false
	var count := maxi(1, int(ceil(delta / (1.0 / 60.0))))
	var step_delta := delta / count
	for tick in range(count):
		var was_grounded := grounded
		grounded = false
		var impulse_delta := minf(step_delta, impulse_remaining)
		body.velocity.x = horizontal_speed + impulse_speed * impulse_delta / step_delta
		impulse_remaining = maxf(0.0, impulse_remaining - step_delta)
		var gravity := reaction_gravity if reaction_gravity >= 0.0 else profile.gravity
		body.velocity.y = minf(body.velocity.y + gravity * gravity_scale * step_delta, profile.maximum_fall_speed)
		var remaining := body.velocity * step_delta
		for iteration in range(6):
			remaining = _limit_displacement(remaining)
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
		if grounded:
			reaction_gravity = -1.0
#endregion
