extends CharacterBody2D
class_name BattleEntity2D
#region 实体与战斗状态
@export var action_profile: BattleActionProfile2D
@export var animation_path: NodePath = ^"AnimationAdapter"
@export var show_registration: bool = true
var entity_id: StringName = &""
var definition_id: StringName = &""
var faction_id: StringName = &"neutral"
var session: BattleSession
var attributes: GameplayVitalAttributeComponent
var abilities: GameplayAbilityComponent
var statuses: GameplayStatusComponent
var animation: CharacterAnimationAdapter
var action_state := BattleActionState2D.new()
var move_axis: float = 0.0
var running: bool = false
var last_impact_time: float = -1.0
var _impact_display: float = 0.0
var _cleaned: bool = false
var operations: BattlePlayerOperations
var motion := BattleMotionController2D.new()
var combo := BattleComboState.new()
var super_armor: bool = false
var _active_skill_id: StringName = &""
var _impact_context: Dictionary = {}
#endregion
#region 初始化与清理
func initialize_battle(owner_session: BattleSession, id: StringName, data: BattleEntityDefinition) -> void:
	assert(entity_id.is_empty(), "战斗实体不能重复初始化")
	session = owner_session
	entity_id = id
	definition_id = data.definition_id
	faction_id = data.faction_id
	var components := BattleGASBinding.attach(self, session, data)
	attributes = components[0]
	abilities = components[1]
	statuses = components[2]
	attributes.vital_depleted.connect(_on_vital_depleted)
	(attributes.get_vital(&"health") as HealthVital).damage_applied.connect(_on_damage_applied)
	for status_id in data.initial_status_ids:
		apply_status_definition(status_id, self)

func _ready() -> void:
	motion.body = self
	combo.definition = action_profile.combo
	assert(combo.definition == null or combo.definition.is_valid(), "连击定义无效")
	animation = get_node_or_null(animation_path) as CharacterAnimationAdapter
	assert(animation != null and action_profile != null, "2D 实体需要独立动画层和动作规则配置")
	animation.action_completed.connect(_on_animation_completed)
	animation.play_action(&"idle")
	CoreSystem.event_bus.event_pushed.connect(_on_core_event)

func cleanup_battle() -> void:
	if _cleaned:
		return
	_cleaned = true
	BattleGASBinding.cleanup(abilities, statuses)
	if CoreSystem.event_bus.event_pushed.is_connected(_on_core_event):
		CoreSystem.event_bus.event_pushed.disconnect(_on_core_event)

func _exit_tree() -> void:
	cleanup_battle()
#endregion
#region 固定物理与动画时间
func advance_input(unscaled_delta: float) -> void:
	if is_instance_valid(operations):
		operations.advance_input(unscaled_delta)

func advance_simulation(delta: float) -> void:
	if delta <= 0.0 or animation == null:
		return
	if is_instance_valid(operations):
		operations.advance_simulation(delta)
	var movable := action_state.get_permission(&"move", action_profile)
	var horizontal := move_axis * attributes.get_value(&"runSpeed" if running else &"walkSpeed") if movable else 0.0
	if action_state.get_permission(&"turn", action_profile) and not is_zero_approx(move_axis):
		animation.set_facing(1 if move_axis > 0.0 else -1)
	var step := combo.get_step()
	if step != null and action_state.elapsed < step.root_motion_frames / step.source_fps:
		# 帧窗口结束所在 tick 只执行窗口内的技能位移，避免额外多走一整 tick。
		var active_delta := minf(delta, step.root_motion_frames / step.source_fps - action_state.elapsed)
		horizontal += step.root_motion_speed * animation.get_facing() * active_delta / delta
	motion.advance(delta, horizontal, action_profile)
	action_state.grounded = motion.grounded
	if combo.is_active() and not motion.grounded:
		_cancel_abilities()
		action_state.enter(BattleActionState2D.State.JUMP)
	if motion.just_landed:
		publish_battle_event(&"battle.motion.landed", {"landing_serial": motion.landing_serial})
	## 本 tick 先更新世界位置和姿态，再让 GAS 发送素材帧攻击事件。
	animation.advance_animation(delta)
	abilities.advance_simulation(delta)
	statuses.advance_simulation(delta)
	attributes.advance_simulation(delta)
	var attack_active := combo.is_active() or (not _active_skill_id.is_empty() and abilities.get_ability_instance(_active_skill_id).is_active)
	action_state.advance(delta, action_profile, not is_zero_approx(velocity.x), running, motion.just_landed, attack_active)
	_advance_combo()
	_update_animation_command()
	_impact_display = maxf(0.0, _impact_display - delta)
	queue_redraw()

func _update_animation_command() -> void:
	var action: StringName = &"idle"
	match action_state.current:
		BattleActionState2D.State.MOVE: action = &"move"
		BattleActionState2D.State.RUN: action = &"run"
		BattleActionState2D.State.TAKEOFF, BattleActionState2D.State.JUMP: action = &"fall" if velocity.y > 0.0 else (&"jump_2" if motion.jump_count >= 2 else &"jump")
		BattleActionState2D.State.LAND: action = &"land"
		BattleActionState2D.State.ATTACK: action = combo.get_step().action if combo.is_active() else StringName(action_state.active_rules.get("animation", &"attack_1"))
		BattleActionState2D.State.HURT: action = &"hurt"
		BattleActionState2D.State.DEAD: action = &"death"
	animation.play_action(action)
#endregion
#region 战斗命令
func is_alive() -> bool:
	return attributes.get_vital_value(&"health") > 0.0 and action_state.current != BattleActionState2D.State.DEAD

func try_attack() -> bool:
	if session.is_simulation_blocked() or not action_state.can_attack(is_alive()):
		return false
	return _start_combo_step(0) if combo.definition != null else try_activate_skill(action_profile.attack_skill_id)

func request_attack() -> bool:
	if session.is_simulation_blocked() or not is_alive():
		return false
	if action_state.current == BattleActionState2D.State.ATTACK and combo.is_active():
		return combo.queue_next()
	return try_attack()

func cancel_operation_commands() -> void:
	combo.queued_next = false

func try_jump() -> bool:
	if session.is_simulation_blocked() or not action_state.can_jump(is_alive(), action_profile) or not motion.can_jump(action_profile.maximum_jumps):
		return false
	if not motion.jump(action_profile):
		return false
	_cancel_abilities()
	action_state.grounded = false
	action_state.enter(BattleActionState2D.State.TAKEOFF)
	animation.play_action(&"jump_2" if motion.jump_count >= 2 else &"jump", true)
	publish_battle_event(&"battle.motion.jump", {"jump_count": motion.jump_count, "jump_serial": motion.jump_serial})
	return true

func try_activate_skill(id: StringName, context: Dictionary = {}) -> bool:
	if session.is_simulation_blocked() or not is_alive() or not abilities.has_ability(id):
		return false
	if combo.definition != null:
		for index in range(combo.definition.steps.size()):
			if combo.definition.steps[index].ability_id == id:
				return _start_combo_step(index)
	if not action_state.can_attack(is_alive()):
		return false
	if not abilities.can_activate_ability(id, context) or not abilities.try_activate_ability(id, context):
		return false
	_active_skill_id = id
	combo.hit_targets.clear()
	action_state.enter(BattleActionState2D.State.ATTACK)
	action_state.active_rules = context.get("action_rules", {}).duplicate(true)
	animation.play_action(StringName(action_state.active_rules.get("animation", &"attack_1")), true)
	return true

func _start_combo_step(index: int, continuing: bool = false) -> bool:
	if combo.definition == null or index < 0 or index >= combo.definition.steps.size():
		return false
	if session.is_simulation_blocked() or not is_alive() or not motion.grounded or (not continuing and not action_state.can_attack(true)):
		return false
	var step: BattleAttackStep2D = combo.definition.steps[index]
	if not abilities.has_ability(step.ability_id) or not abilities.can_activate_ability(step.ability_id):
		return false
	if not abilities.try_activate_ability(step.ability_id, {"combo_step": index + 1}):
		return false
	combo.begin(index)
	_active_skill_id = step.ability_id
	action_state.enter(BattleActionState2D.State.ATTACK)
	action_state.active_rules = step.get_rules()
	animation.play_action(step.action, true)
	publish_battle_event(&"battle.combo.started", {"combo_step": index + 1, "ability_id": step.ability_id, "cast_serial": combo.cast_serial})
	return true

func _advance_combo() -> void:
	if not combo.is_active() or abilities.get_ability_instance(combo.get_step().ability_id).is_active:
		return
	var next := combo.index + 1
	var queued := combo.queued_next
	combo.cancel()
	_active_skill_id = &""
	if queued and _start_combo_step(next, true):
		return
	action_state.advance(0.0, action_profile, not is_zero_approx(velocity.x), running)
	publish_battle_event(&"battle.combo.finished")

func receive_damage(amount: float, instigator: Node = null, interrupt_kind: StringName = &"normal", interrupt_priority: int = 60) -> float:
	if session.is_simulation_blocked() or not is_alive():
		return 0.0
	var info := DamageInfo.new(instigator, attributes, amount)
	info.final_damage = amount
	info.set_meta(&"interrupt_kind", interrupt_kind)
	info.set_meta(&"interrupt_priority", interrupt_priority)
	return (attributes.get_vital(&"health") as HealthVital).apply_damage(info, self)

func _cancel_abilities() -> void:
	combo.cancel()
	_active_skill_id = &""
	for id in abilities.get_all_ability_ids():
		abilities.get_ability_instance(id).end_ability()

func _on_vital_depleted(id: StringName) -> void:
	if id != &"health":
		return
	_cancel_abilities()
	action_state.enter(BattleActionState2D.State.DEAD)
	move_axis = 0.0
	velocity.x = 0.0
	if is_instance_valid(operations):
		operations.set_control_blocked(&"dead", true)
	if animation != null:
		animation.play_action(&"death", true)
	publish_battle_event(&"battle.entity_died")

func _on_damage_applied(info: DamageInfo, _damage: float) -> void:
	if is_alive():
		var armored := super_armor or bool(action_state.active_rules.get("super_armor", false)) or TagManager.has_tag(self, &"state.super_armor")
		var kind := StringName(info.get_meta(&"interrupt_kind", &"normal"))
		if not action_state.can_interrupt(kind, int(info.get_meta(&"interrupt_priority", 60)), armored, action_profile):
			publish_battle_event(&"battle.interrupt_rejected", {"interrupt_kind": kind})
			return
		_cancel_abilities()
		action_state.enter(BattleActionState2D.State.HURT)
		if animation != null:
			animation.play_action(&"hurt", true)

func _on_animation_completed(action: StringName) -> void:
	## 只通知动作系统；此回调不改变战斗状态、生命或技能许可。
	publish_battle_event(&"battle.animation_completed", {"action": action})
#endregion
#region 原版攻击区域与 Core 事件
func get_attack_rect_local(context: Dictionary = {}) -> Rect2:
	var rect := action_profile.attack_rect
	if float(context.get("hit_scale_x", 1.0)) < 0.0:
		rect.position.x = -rect.end.x
	rect.position += Vector2(context.get("hit_offset", Vector2.ZERO))
	if animation.get_facing() < 0:
		rect.position.x = -rect.end.x
	return Rect2(rect.position * action_profile.source_unit_scale, rect.size * action_profile.source_unit_scale)

func get_attack_rect_global(context: Dictionary = {}) -> Rect2:
	return global_transform * get_attack_rect_local(context)

func get_attack_position() -> Vector2:
	return to_global(get_attack_rect_local().get_center())

func get_body_rect_global() -> Rect2:
	var collision := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	return collision.global_transform * collision.shape.get_rect() if collision != null else Rect2(global_position, Vector2.ZERO)

func _on_core_event(event_id: String, payload: Array) -> void:
	if event_id != "battle.attack.impact" or payload.size() != 1 or not payload[0] is Dictionary:
		return
	var context: Dictionary = payload[0]
	if context.get("entity") != self or context.get("battle_id") != session.battle_id or not is_alive():
		return
	if _active_skill_id.is_empty() or context.get("ability_id") != _active_skill_id or not abilities.get_ability_instance(_active_skill_id).is_active:
		return
	last_impact_time = context.skill_time
	_impact_context = context.duplicate(true)
	_impact_display = 0.16
	var rect := get_attack_rect_global(context)
	for target in session.get_entities():
		if not is_alive():
			break
		if not target is BattleEntity2D or target == self or not target.is_alive():
			continue
		if session.factions.is_hostile(faction_id, target.faction_id) and rect.intersects(target.get_body_rect_global()):
			if not combo.register_hit(int(context.get("hit_index", 1)), target.entity_id):
				continue
			var damage := DamageCalculator.calculate_final_damage(target, self, context)
			target.receive_damage(damage, self)
			session.publish_event(&"battle.attack.hit", self, target, {"damage": damage, "skill_time": context.skill_time, "source_frame": context.source_frame, "combo_step": context.get("combo_step", 0), "hit_index": context.get("hit_index", 1), "ability_id": context.ability_id})

func publish_battle_event(event_id: StringName, payload: Dictionary = {}) -> void:
	session.publish_event(event_id, self, self, payload)

func get_battle_random_int(minimum: int, maximum: int, stream: StringName = &"combat") -> int:
	return session.random.random_int(minimum, maximum, stream)

func apply_status_definition(id: StringName, instigator: Node = null) -> GameplayStatusInstance:
	var data := session.catalog.instantiate_definition("statuses", id) as GameplayStatusData
	return statuses.apply_status(data, instigator if instigator != null else self) if data != null else null

func accepts_status_event(context: Dictionary) -> bool:
	if context.has("battle_id") and context.battle_id != session.battle_id:
		return false
	if context.has("entity"):
		return context.entity == self
	if context.get("target_entity_id", &"") != &"":
		return context.target_entity_id == entity_id
	return context.get("battle_id", &"") == session.battle_id

func get_gameplay_vital_attribute_component() -> GameplayVitalAttributeComponent:
	return attributes

func get_gameplay_ability_component() -> GameplayAbilityComponent:
	return abilities

func get_gameplay_status_component() -> GameplayStatusComponent:
	return statuses
#endregion
#region 场景检查标记
func _draw() -> void:
	if not show_registration or animation == null:
		return
	draw_line(Vector2(-14, 0), Vector2(14, 0), Color("59e8c0"), 2)
	draw_line(Vector2(0, -12), Vector2(0, 12), Color("59e8c0"), 2)
	if _impact_display > 0.0:
		draw_rect(get_attack_rect_local(_impact_context), Color(1, 0.65, 0.15, 0.16), true)
		draw_rect(get_attack_rect_local(_impact_context), Color("ffd080"), false, 2)
	for socket in [&"weapon", &"weapon_alt", &"weapon_long"]:
		if not animation.is_socket_active(socket):
			continue
		var point := to_local(animation.get_socket_global_transform(socket).origin)
		draw_circle(point, 3, Color("ffd080"))
#endregion
