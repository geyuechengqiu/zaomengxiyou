extends BaseState
class_name BattleActionLeafState2D
#region Core 叶子状态与实例数据
enum Kind { IDLE, MOVE, JUMP, ATTACK, HURT, DEAD, RUN, TAKEOFF, LAND }
enum OperationResult { ACCEPTED, RETRY, UNAVAILABLE, NOT_HANDLED }
const NAMES: Array[StringName] = [&"IDLE", &"MOVE", &"AIR", &"ATTACK", &"HURT", &"DEAD", &"RUN", &"TAKEOFF", &"LAND"]
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
		if not can_attack(actor.is_alive(), machine.grounded):
			return OperationResult.RETRY
		return OperationResult.ACCEPTED if actor.try_activate_skill(id, {"operation": intent.action}) else OperationResult.RETRY
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
	if kind == Kind.ATTACK and machine.attack_active:
		return
	if kind == Kind.HURT and elapsed + 0.000000001 < profile.hurt_lock_frames / profile.source_fps:
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
