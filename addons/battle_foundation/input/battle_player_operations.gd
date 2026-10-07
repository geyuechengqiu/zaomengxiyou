extends Node
class_name BattlePlayerOperations
#region 公共角色操作接入
enum Result { ACCEPTED, RETRY, UNAVAILABLE, NOT_HANDLED }
signal operation_observed(intent: CoreOperationIntent)
@export var operation_profile: CoreOperationProfile
## skill_1..skill_5 / magic_weapon / wushuang 等语义槽位到 GAS 技能 ID。
@export var ability_slots: Dictionary[StringName, StringName] = {}
@export var device_filter: int = -1
@export var enabled: bool = true:
	set(value):
		enabled = value
		if controller != null:
			controller.set_control_blocked(&"ownership", not value)
var controller: CoreOperationController
var actor: BattleEntity2D
var _phases: Array[CoreOperationIntent] = []
#endregion
#region 装配与控制权
func _ready() -> void:
	actor = get_parent() as BattleEntity2D
	assert(actor != null and operation_profile != null, "玩家操作需要 2D 战斗实体与操作配置")
	assert(CoreSystem.operation_manager != null, "请启用 Core operation_manager")
	controller = CoreSystem.operation_manager.create_controller(StringName("%s/operations" % actor.entity_id), operation_profile, device_filter)
	assert(controller != null)
	controller.externally_driven = true
	controller.intent_emitted.connect(_on_intent)
	controller.control_changed.connect(_on_control_changed)
	add_child(controller)
	controller.set_control_blocked(&"ownership", not enabled)

func advance_input(unscaled_delta: float) -> void:
	controller.set_control_blocked(&"battle_paused", actor.session.clock.paused or actor.session.clock.time_scale <= 0.0)
	controller.set_control_blocked(&"dead", not actor.is_alive())
	controller.advance_input(unscaled_delta)

func set_control_blocked(reason: StringName, blocked: bool) -> void:
	controller.set_control_blocked(reason, blocked)

func _on_control_changed(available: bool, _reasons: Array) -> void:
	if not available:
		actor.move_axis = 0.0
		actor.running = false
		actor.cancel_operation_commands()
		_phases.clear()

func _exit_tree() -> void:
	if is_instance_valid(actor):
		actor.move_axis = 0.0
		actor.running = false
	if is_instance_valid(controller):
		controller.reset(&"owner_exited")
#endregion
#region 固定物理 tick 消费
func advance_simulation(_delta: float) -> void:
	if not controller.has_control() or not actor.is_alive():
		return
	actor.move_axis = controller.get_axis(&"move")
	actor.running = controller.is_pressed(&"run") or controller.get_double_tap_direction(&"move") != 0
	var commands := controller.peek_buffered_intents()
	commands.append_array(_phases)
	_phases.clear()
	# 短按也必须先分发 pressed，再分发 held/released，角色蓄力才不会倒序。
	commands.sort_custom(func(left: CoreOperationIntent, right: CoreOperationIntent): return left.sequence < right.sequence)
	for intent in commands:
		if intent.phase != CoreOperationIntent.Phase.PRESSED:
			_handle_character_phase(intent)
			continue
		var result := _handle_common_intent(intent)
		if result == Result.NOT_HANDLED:
			result = _handle_character_intent(intent)
		if result == Result.RETRY:
			continue
		controller.consume_buffered_intent(intent.sequence)
		_after_common_intent(intent, result)
		actor.publish_battle_event(&"battle.operation_result", {"intent": intent.action, "input_sequence": intent.sequence, "result": Result.keys()[result]})
#endregion
#region 公共操作与角色扩展钩子
func _handle_common_intent(intent: CoreOperationIntent) -> Result:
	match intent.action:
		&"attack":
			return Result.ACCEPTED if actor.request_attack() else Result.RETRY
		&"jump":
			if intent.payload.get("held_intents", []).has(&"move_down"):
				return Result.NOT_HANDLED
			return Result.ACCEPTED if actor.try_jump() else Result.RETRY
	if ability_slots.has(intent.action):
		var id: StringName = ability_slots[intent.action]
		if id.is_empty() or not actor.abilities.has_ability(id):
			return Result.UNAVAILABLE
		if actor.action_state.current in [BattleActionState2D.State.ATTACK, BattleActionState2D.State.HURT, BattleActionState2D.State.DEAD]:
			return Result.RETRY
		return Result.ACCEPTED if actor.try_activate_skill(id, {"operation": intent.action}) else Result.RETRY
	return Result.NOT_HANDLED

## 子类追加专属按下分支；不得读取按键或绕过 actor 的战斗许可。
func _handle_character_intent(_intent: CoreOperationIntent) -> Result:
	return Result.UNAVAILABLE

## 公共操作消费后追加角色行为；RETRY 不调用，避免缓存重试重复执行副作用。
func _after_common_intent(_intent: CoreOperationIntent, _result: Result) -> void:
	pass

## 持续按住、正常松开在战斗 tick 分发，可实现蓄力/释放；取消走独立钩子。
func _handle_character_phase(_intent: CoreOperationIntent) -> void:
	pass

## 菜单、失焦、换控制者时同步取消本地蓄力等操作，不在此发动技能。
func _handle_cancelled_intent(_intent: CoreOperationIntent) -> void:
	pass
#endregion
#region 意图观察与 Core 发布
func _on_intent(intent: CoreOperationIntent) -> void:
	var snapshot := intent.copy_intent()
	operation_observed.emit(snapshot.copy_intent())
	actor.publish_battle_event(&"battle.operation_intent", {"intent": snapshot.action, "phase": snapshot.get_phase_name(), "strength": snapshot.strength, "held_seconds": snapshot.held_seconds, "input_time": snapshot.input_time, "input_sequence": snapshot.sequence, "controller_id": controller.controller_id, "operation_payload": snapshot.payload})
	if snapshot.payload.get("cancelled", false):
		_handle_cancelled_intent(snapshot)
	elif snapshot.phase in [CoreOperationIntent.Phase.HELD, CoreOperationIntent.Phase.RELEASED]:
		## 同一冻结期间仅保留最新 held，保持正常 release 的次序。
		if snapshot.phase == CoreOperationIntent.Phase.HELD:
			for index in range(_phases.size() - 1, -1, -1):
				if _phases[index].action == snapshot.action and _phases[index].phase == CoreOperationIntent.Phase.RELEASED:
					break
				if _phases[index].action == snapshot.action and _phases[index].phase == snapshot.phase:
					_phases.remove_at(index)
		while _phases.size() >= 64:
			_phases.pop_front()
		_phases.append(snapshot)
#endregion
