extends BaseStateMachine
class_name BattleActionStateMachine2D
#region 战斗更新上下文
var profile: BattleActionProfile2D
var grounded: bool = false
var moving: bool = false
var move_axis: float = 0.0
var running: bool = false
var just_landed: bool = false
var attack_active: bool = false
var _disposed: bool = false

func _init() -> void:
	for kind in BattleActionLeafState2D.Kind.values():
		add_state(BattleActionLeafState2D.NAMES[kind], BattleActionLeafState2D.new(kind))
	start(&"IDLE")
#endregion
#region 语义操作交给当前 Core 叶子
func handle_operation(intent: CoreOperationIntent, slots: Dictionary = {}) -> BattleActionLeafState2D.OperationResult:
	if _disposed or not is_active or is_terminal_dead() or not is_instance_valid(agent):
		return BattleActionLeafState2D.OperationResult.UNAVAILABLE
	return (current_state as BattleActionLeafState2D).handle_operation(intent, slots)

func clear_operation_state() -> void:
	move_axis = 0.0
	running = false
	moving = false
	if is_instance_valid(agent):
		agent.cancel_operation_commands()
	if is_active and grounded and current_state.kind in [BattleActionLeafState2D.Kind.MOVE, BattleActionLeafState2D.Kind.RUN]:
		transition_local(&"IDLE")
#endregion
#region Core 状态切换与死亡终态
func is_terminal_dead() -> bool:
	return bool(values.get(&"terminal_dead", false))

func start(initial_state: StringName = &"", msg: Dictionary = {}, resume_previous: bool = false) -> void:
	if _disposed:
		return
	var target := previous_state if resume_previous and not previous_state.is_empty() else initial_state
	if is_terminal_dead() and target != &"DEAD":
		return
	super.start(initial_state, msg, resume_previous)

func transition_local(next: StringName, msg: Dictionary = {}) -> void:
	# 叶子 transition_to、Core 管理器和旧接口均经过此守卫。
	if _disposed or not is_active or is_terminal_dead():
		return
	super.transition_local(next, msg)
#endregion
#region 注销后断开 RefCounted 所属关系
func _dispose() -> void:
	if _disposed:
		return
	_disposed = true
	for state in states.values():
		state.state_machine = null
		state.agent = null
	states.clear()
	values.clear()
	profile = null
	agent = null
#endregion
