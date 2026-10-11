extends Node
class_name BattleAIController2D
#region 场景预置AI组件及独立运行状态
@export var enabled: bool = true
@export var profile: BattleAIProfile2D
var actor: BattleEntity2D
var home: Vector2
var target: BattleEntity2D
var state: StringName = &"IDLE"
var returning: bool = false
var retreat_remaining: float = 0.0
var patrol_remaining: float = 0.0
var patrol_direction: int = 1
var decision_remaining: float = 0.0
var successful_casts: int = 0
var _was_attacking: bool = false
var _last_axis: float = INF
var _jump_remaining: float = 0.0
var _step_delta: float = 0.0
signal decision_changed(next: StringName)

func bind(owner_actor: BattleEntity2D) -> void:
	actor = owner_actor
	home = actor.global_position
	assert(profile != null and profile.is_valid(), "怪物AI需要有效的Profile/Policy/TargetSelector")

func skill_ready() -> bool:
	return not profile.attack_skill_id.is_empty() and actor.abilities.has_ability(profile.attack_skill_id) and actor.abilities.can_activate_ability(profile.attack_skill_id, {})

func movement_to(destination_x: float) -> float:
	var distance := destination_x - actor.global_position.x
	var movement := actor.attributes.get_value(&"walkSpeed") * maxf(profile.decision_interval, _step_delta)
	return signf(distance) * minf(1.0, absf(distance) / maxf(1.0, movement))
#endregion
#region 统一战斗时钟驱动，不启用独立_process
func advance_simulation(delta: float) -> void:
	if actor == null or actor.session.is_simulation_blocked():
		return
	_step_delta = delta
	if not enabled or not actor.is_alive():
		target = null
		set_state(&"DISABLED" if actor.is_alive() else &"DEAD")
		_stop_movement()
		return
	retreat_remaining = maxf(0.0, retreat_remaining - delta)
	patrol_remaining = maxf(0.0, patrol_remaining - delta)
	_jump_remaining = maxf(0.0, _jump_remaining - delta)
	var attacking := actor.attack_instance != null and actor.attack_instance.active
	if _was_attacking and not attacking and actor.action_state.can_attack(true):
		if actor.session.random.random_float(&"ai") < profile.retreat_chance:
			retreat_remaining = lerpf(profile.retreat_minimum, profile.retreat_maximum, actor.session.random.random_float(&"ai"))
	_was_attacking = attacking
	# 不向受控/受击/死亡状态持续塞入攻击缓存；恢复后才重新决策。
	if attacking or not actor.action_state.get_permission(&"move", actor.action_profile):
		set_state(&"CASTING" if attacking else &"CONTROLLED")
		_stop_movement()
		decision_remaining = 0.0
		return
	decision_remaining -= delta
	if decision_remaining > 0.0 and (target == null or (is_instance_valid(target) and target.is_alive())):
		return
	decision_remaining = profile.decision_interval
	if not returning:
		var had_target := is_instance_valid(target)
		target = profile.target_selector.select_target(actor, profile, home)
		if had_target and target == null and absf(actor.global_position.x - home.x) > profile.home_tolerance:
			returning = true
	var decision: Dictionary = profile.policy.call("decide", self)
	set_state(StringName(decision.get("state", &"IDLE")))
	var axis := clampf(float(decision.get("axis", 0.0)), -1.0, 1.0)
	# 边界处仅允许朝出生点移动，逃离也不能把怪物带出活动范围。
	if absf(actor.global_position.x - home.x) >= profile.leash_radius and signf(axis) == signf(actor.global_position.x - home.x):
		axis = 0.0
	_submit_movement(axis)
	if actor.action_state.get_permission(&"turn", actor.action_profile) and int(decision.get("facing", 0)) != 0:
		actor.animation.set_facing(int(decision.facing))
	if bool(decision.get("jump", false)) and _jump_remaining <= 0.0:
		_submit(&"jump")
		_jump_remaining = 0.6
	var skill := StringName(decision.get("skill", &""))
	if not skill.is_empty() and actor.action_state.can_attack(true):
		if _submit(&"ai_skill", {&"ai_skill": skill}) == BattleActionLeafState2D.OperationResult.ACCEPTED:
			successful_casts += 1
			_was_attacking = true
			set_state(&"CASTING")

func set_state(next: StringName) -> void:
	if state != next:
		state = next
		decision_changed.emit(next)

func _stop_movement() -> void:
	# DEAD拒绝所有输入，但必须先清除上一次移动快照。
	if actor.action_state.current == BattleActionState2D.State.DEAD:
		actor.move_axis = 0.0
		actor.running = false
		_last_axis = 0.0
	else:
		_submit_movement(0.0)
	actor.cancel_operation_commands()

func _submit_movement(axis: float) -> void:
	if is_equal_approx(_last_axis, axis):
		return
	_last_axis = axis
	var intent := CoreOperationIntent.new()
	intent.action = &"move_left" if axis < 0.0 else &"move_right"
	intent.origin = &"ai"
	intent.phase = CoreOperationIntent.Phase.CHANGED
	intent.pressed = not is_zero_approx(axis)
	intent.payload = {"move_axis": axis, "running": false}
	actor.action_state.handle_operation(intent)

func _submit(operation: StringName, slots: Dictionary = {}) -> BattleActionLeafState2D.OperationResult:
	var intent := CoreOperationIntent.new()
	intent.action = operation
	intent.origin = &"ai"
	intent.pressed = true
	intent.phase = CoreOperationIntent.Phase.PRESSED
	return actor.action_state.handle_operation(intent, slots)
#endregion
