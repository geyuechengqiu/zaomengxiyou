extends Node
class_name BattleActionState2D
#region 兼容入口：状态与时间只读取 Core 当前叶子
const State = BattleActionLeafState2D.Kind
var machine := BattleActionStateMachine2D.new()
var registration_id: StringName = &""
var _manager: WeakRef
var _disposed: bool = false
var current: State:
	get:
		var state := _get_leaf()
		return state.kind if state != null else (State.DEAD if machine.is_terminal_dead() else State.IDLE)
var elapsed: float:
	get:
		var state := _get_leaf()
		return state.elapsed if state != null else 0.0
var grounded: bool:
	get:
		return machine.grounded
	set(value):
		machine.grounded = value
var active_rules: Dictionary:
	get:
		var state := _get_leaf()
		return state.active_rules if state != null else {}
	set(value):
		var state := _get_leaf()
		if state != null:
			state.active_rules = value.duplicate(true)
#endregion
#region Core 注册、查询与实例清理
func bind(owner_entity: BattleEntity2D) -> void:
	assert(registration_id.is_empty() and not _disposed, "动作状态机只能绑定一次")
	registration_id = StringName("battle.actions.%s.%s" % [owner_entity.session.battle_id, owner_entity.entity_id])
	machine.state_id = registration_id
	machine.profile = owner_entity.action_profile
	var manager := CoreSystem.state_machine_manager
	assert(manager != null, "动作状态依赖 Core StateMachineManager")
	_manager = weakref(manager)
	# 仅登记与监控；combat delta 是状态机唯一更新源，原始输入交给 Core 操作控制器。
	manager.register_state_machine(registration_id, machine, owner_entity, &"", {}, false, false, false)

func dispose() -> void:
	if _disposed:
		return
	_disposed = true
	var manager: Variant = _manager.get_ref() if _manager != null else null
	if is_instance_valid(manager) and manager.get_state_machine(registration_id) == machine:
		manager.unregister_state_machine(registration_id)
	else:
		machine.stop()
		machine.dispose()
	registration_id = &""
	_manager = null

func _exit_tree() -> void:
	dispose()

func _notification(what: int) -> void:
	# 编辑器/资源校验中，实例可能从未入树就被释放。
	if what == NOTIFICATION_PREDELETE:
		dispose()

func _get_leaf() -> BattleActionLeafState2D:
	return machine.current_state as BattleActionLeafState2D
#endregion
#region 委托当前 Core 叶子的战斗权限
func can_attack(alive: bool) -> bool:
	var state := _get_leaf()
	return machine.is_active and state != null and state.can_attack(alive, grounded)

func can_jump(alive: bool, profile: BattleActionProfile2D = null) -> bool:
	return alive and current != State.DEAD and (get_permission(&"jump", profile) if profile != null else can_attack(alive))

func get_permission(permission: StringName, profile: BattleActionProfile2D) -> bool:
	var state := _get_leaf()
	return machine.is_active and state != null and state.get_permission(permission, profile)

func can_interrupt(kind: StringName, priority: int, armored: bool, profile: BattleActionProfile2D) -> bool:
	var state := _get_leaf()
	return machine.is_active and state != null and state.can_interrupt(kind, priority, armored, profile)
#endregion
#region 语义命令与固定战斗时间
func handle_operation(intent: CoreOperationIntent, slots: Dictionary = {}) -> BattleActionLeafState2D.OperationResult:
	return machine.handle_operation(intent, slots)

func clear_operation_state() -> void:
	machine.clear_operation_state()

func enter(next: State, rules: Dictionary = {}) -> void:
	machine.transition_local(BattleActionLeafState2D.NAMES[next], {"action_rules": rules})

func advance(delta: float, profile: BattleActionProfile2D, moving: bool, running: bool = false, just_landed: bool = false, attack_active: bool = false) -> void:
	if _disposed or not is_finite(delta) or delta < 0.0:
		return
	machine.profile = profile
	machine.moving = moving
	machine.running = running
	machine.just_landed = just_landed
	machine.attack_active = attack_active
	machine.physics_update(delta)

func get_state_name() -> String:
	return String(machine.get_current_state_name())
#endregion
