extends RefCounted
class_name BattleActionState2D
#region 独立战斗状态
enum State { IDLE, MOVE, JUMP, ATTACK, HURT, DEAD, RUN, TAKEOFF, LAND }
var current: State = State.IDLE
var elapsed: float = 0.0
var grounded: bool = false
var active_rules: Dictionary = {}
#endregion
#region 状态规则
func can_attack(alive: bool) -> bool:
	return alive and grounded and current in [State.IDLE, State.MOVE, State.RUN, State.LAND]

func can_jump(alive: bool, profile: BattleActionProfile2D = null) -> bool:
	return alive and current != State.DEAD and (get_permission(&"jump", profile) if profile != null else can_attack(alive))

func get_permission(permission: StringName, profile: BattleActionProfile2D) -> bool:
	if current == State.DEAD:
		return false
	var rules: Dictionary = profile.state_rules.get(StringName(State.keys()[current]), {})
	return bool(active_rules.get(String(permission), rules.get(String(permission), false)))

func can_interrupt(kind: StringName, priority: int, armored: bool, profile: BattleActionProfile2D) -> bool:
	if kind == &"death":
		return true
	if current == State.DEAD or (armored and kind == &"normal"):
		return false
	var rules: Dictionary = profile.state_rules.get(StringName(State.keys()[current]), {})
	var allowed: Array = active_rules.get("interrupt_kinds", rules.get("interrupt_kinds", [&"normal", &"heavy", &"launch"]))
	return allowed.has(kind) and priority >= int(active_rules.get("interrupt_priority", rules.get("interrupt_priority", 0)))

func enter(next: State) -> void:
	## 死亡为终态，复位必须重新生成实体。
	if current == State.DEAD:
		return
	current = next
	elapsed = 0.0
	active_rules = {}

func advance(delta: float, profile: BattleActionProfile2D, moving: bool, running: bool = false, just_landed: bool = false, attack_active: bool = false) -> void:
	elapsed += delta
	if current == State.DEAD:
		return
	if current == State.ATTACK and attack_active:
		return
	if current == State.HURT and elapsed + 0.000000001 < profile.hurt_lock_frames / profile.source_fps:
		return
	if just_landed and grounded:
		enter(State.LAND)
		return
	if current == State.TAKEOFF and not grounded and elapsed < profile.takeoff_frames / profile.source_fps:
		return
	if current == State.LAND and grounded and elapsed < profile.landing_frames / profile.source_fps:
		return
	var next: State = State.JUMP if not grounded else (State.RUN if moving and running else (State.MOVE if moving else State.IDLE))
	if current != next:
		enter(next)

func get_name() -> String:
	return ["IDLE", "MOVE", "AIR", "ATTACK", "HURT", "DEAD", "RUN", "TAKEOFF", "LAND"][current]
#endregion
