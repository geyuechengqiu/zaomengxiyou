extends BaseState
class_name BattleActionLeafState2D
#region Core 叶子状态与实例数据
enum Kind { IDLE, MOVE, JUMP, ATTACK, HURT, DEAD, RUN, TAKEOFF, LAND, LAUNCHED, AIR_HURT, HIT_LAND, KNOCKDOWN, GETUP, PROTECT, RUN_ATTACK, JUMP_ATTACK }
enum OperationResult { ACCEPTED, RETRY, UNAVAILABLE, NOT_HANDLED }
const NAMES: Array[StringName] = [&"IDLE", &"MOVE", &"AIR", &"ATTACK", &"HURT", &"DEAD", &"RUN", &"TAKEOFF", &"LAND", &"LAUNCHED", &"AIR_HURT", &"HIT_LAND", &"KNOCKDOWN", &"GETUP", &"PROTECT", &"RUN_ATTACK", &"JUMP_ATTACK"]
var kind: Kind = Kind.IDLE
var elapsed: float = 0.0
var active_rules: Dictionary = {}

func _init(action_kind: Kind = Kind.IDLE) -> void:
	kind = action_kind
#endregion
#region 当前状态消费操作意图（不读取按键）
func handle_operation(intent: CoreOperationIntent, slots: Dictionary) -> OperationResult:
	var machine: Variant = state_machine
	var actor: BattleEntity2D = agent as BattleEntity2D
	if actor == null or kind == Kind.DEAD:
		return OperationResult.UNAVAILABLE
	if intent.action in [&"move_left", &"move_right", &"run"]:
		# 聚合后的轴快照保留多键、多设备和后按方向优先的语义。
		machine.move_axis = clampf(float(intent.payload.get("move_axis", 0.0)), -1.0, 1.0)
		machine.running = bool(intent.payload.get("running", false))
		machine.moving = not is_zero_approx(machine.move_axis)
		if intent.phase == CoreOperationIntent.Phase.PRESSED and not intent.payload.get("cancelled", false) and intent.action in [&"move_left", &"move_right"]:
			actor.try_turn_combo(-1 if intent.action == &"move_left" else 1)
		if machine.grounded and kind in [Kind.IDLE, Kind.MOVE, Kind.RUN]:
			var next: Kind = Kind.IDLE if not machine.moving else (Kind.RUN if machine.running else Kind.MOVE)
			if next != kind:
				transition_to(NAMES[next])
		return OperationResult.ACCEPTED
	if intent.payload.get("cancelled", false) or intent.phase != CoreOperationIntent.Phase.PRESSED:
		return OperationResult.NOT_HANDLED
	match intent.action:
		&"attack":
			return OperationResult.ACCEPTED if actor.request_attack() else OperationResult.RETRY
		&"jump":
			if intent.payload.get("held_intents", []).has(&"move_down"):
				return OperationResult.NOT_HANDLED
			return OperationResult.ACCEPTED if actor.try_jump() else OperationResult.RETRY
	if slots.has(intent.action):
		var id: StringName = slots[intent.action]
		if id.is_empty() or not actor.abilities.has_ability(id):
			return OperationResult.UNAVAILABLE
		return OperationResult.ACCEPTED if actor.request_skill_operation(intent.action, id) else OperationResult.RETRY
	return OperationResult.NOT_HANDLED
#endregion
#region Core 生命周期与固定战斗更新
func _enter(msg: Dictionary = {}) -> void:
	elapsed = 0.0
	active_rules = msg.get("action_rules", {}).duplicate(true)
	if kind == Kind.DEAD:
		state_machine.set_variable(&"terminal_dead", true)

func _exit() -> void:
	active_rules.clear()

func _physics_update(delta: float) -> void:
	elapsed += delta
	var machine: Variant = state_machine
	var profile: BattleActionProfile2D = machine.profile
	if profile == null or kind == Kind.DEAD:
		return
	if kind in [Kind.ATTACK, Kind.RUN_ATTACK, Kind.JUMP_ATTACK] and machine.attack_active:
		return
	# 受击空中状态不因硬直计时结束而变成可操控的普通跳跃。
	if kind in [Kind.LAUNCHED, Kind.AIR_HURT]:
		if machine.grounded:
			_transition_reaction(Kind.HIT_LAND)
		elif kind == Kind.LAUNCHED and (agent as CharacterBody2D).velocity.y >= 0.0:
			_transition_reaction(Kind.AIR_HURT)
		return
	if kind == Kind.HIT_LAND:
		if not machine.grounded:
			_transition_reaction(Kind.AIR_HURT)
		elif elapsed + 0.000000001 >= float(active_rules.get("hit_landing_seconds", 0.1)):
			if bool(active_rules.get("knockdown_after_land", false)):
				_transition_reaction(Kind.KNOCKDOWN)
			else:
				_transition_locomotion(machine)
		return
	if kind == Kind.KNOCKDOWN:
		if not machine.grounded:
			active_rules["knockdown_after_land"] = true
			_transition_reaction(Kind.AIR_HURT)
		elif elapsed + 0.000000001 >= float(active_rules.get("knockdown_seconds", 0.65)):
			_transition_reaction(Kind.GETUP)
		return
	if kind == Kind.GETUP:
		if not machine.grounded:
			_transition_reaction(Kind.AIR_HURT)
		elif elapsed + 0.000000001 >= float(active_rules.get("getup_seconds", 0.35)):
			_transition_locomotion(machine)
		return
	if kind == Kind.PROTECT:
		if elapsed + 0.000000001 >= float(active_rules.get("protect_seconds", 0.8)):
			_transition_locomotion(machine)
		return
	if kind == Kind.HURT and elapsed + 0.000000001 < float(active_rules.get("hurt_lock_seconds", profile.hurt_lock_frames / profile.source_fps)):
		return
	if kind == Kind.HURT:
		if not machine.grounded:
			_transition_reaction(Kind.AIR_HURT)
			return
		# 地面击退尚未结束时保留反应；跨平台边缘后继续受击下落。
		if is_instance_valid(agent) and (agent as BattleEntity2D).motion.impulse_remaining > 0.000000001:
			return
		if bool(active_rules.get("knockdown_after_land", false)):
			_transition_reaction(Kind.KNOCKDOWN)
			return
	if machine.just_landed and machine.grounded:
		transition_to(NAMES[Kind.LAND])
		return
	if kind == Kind.TAKEOFF and not machine.grounded and elapsed < profile.takeoff_frames / profile.source_fps:
		return
	if kind == Kind.LAND and machine.grounded and elapsed < profile.landing_frames / profile.source_fps:
		return
	var next: Kind = Kind.JUMP if not machine.grounded else (Kind.RUN if machine.moving and machine.running else (Kind.MOVE if machine.moving else Kind.IDLE))
	if kind != next:
		transition_to(NAMES[next])

func _transition_reaction(next: Kind) -> void:
	transition_to(NAMES[next], {"action_rules": active_rules.duplicate(true)})

func _transition_locomotion(machine: Variant) -> void:
	var next: Kind = Kind.JUMP if not machine.grounded else (Kind.RUN if machine.moving and machine.running else (Kind.MOVE if machine.moving else Kind.IDLE))
	transition_to(NAMES[next])
#endregion
#region 每个状态的权限与打断规则
func can_attack(alive: bool, grounded: bool) -> bool:
	return alive and grounded and kind in [Kind.IDLE, Kind.MOVE, Kind.RUN, Kind.LAND]

func get_permission(permission: StringName, profile: BattleActionProfile2D) -> bool:
	if kind == Kind.DEAD:
		return false
	var rules: Dictionary = profile.state_rules.get(StringName(Kind.keys()[kind]), {})
	return bool(active_rules.get(String(permission), rules.get(String(permission), false)))

func can_interrupt(attack_kind: StringName, priority: int, armored: bool, profile: BattleActionProfile2D) -> bool:
	if attack_kind == &"death":
		return true
	if kind == Kind.DEAD or (armored and attack_kind == &"normal"):
		return false
	var rules: Dictionary = profile.state_rules.get(StringName(Kind.keys()[kind]), {})
	var allowed: Array = active_rules.get("interrupt_kinds", rules.get("interrupt_kinds", [&"normal", &"heavy", &"launch"]))
	return allowed.has(attack_kind) and priority >= int(active_rules.get("interrupt_priority", rules.get("interrupt_priority", 0)))
#endregion
