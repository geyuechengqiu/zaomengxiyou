extends CharacterBody2D
class_name BattleEntity2D
#region 实体与战斗状态
@export var action_profile: BattleActionProfile2D
@export var animation_path: NodePath = ^"AnimationAdapter"
@export var attack_hitbox_path: NodePath = ^"AnimationAdapter/AttackHitbox"
@export var hurtbox_path: NodePath = ^"Hurtbox"
@export var show_registration: bool = true
var entity_id: StringName = &""
var definition_id: StringName = &""
var faction_id: StringName = &"neutral"
var session: BattleSession
var attributes: BattleAttributeComponent
var abilities: GameplayAbilityComponent
var statuses: GameplayStatusComponent
var animation: CharacterAnimationAdapter
var attack_hitbox: BattleHitbox2D
var hurtbox: BattleHurtbox2D
var attack_instance: BattleAttackInstance
var _attack_serial: int = 0
var feedback: BattleCombatFeedback2D
var action_state := BattleActionState2D.new()
var move_axis: float:
	get:
		return action_state.machine.move_axis
	set(value):
		action_state.machine.move_axis = clampf(value, -1.0, 1.0)
var running: bool:
	get:
		return action_state.machine.running
	set(value):
		action_state.machine.running = value
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
	attack_hitbox = get_node_or_null(attack_hitbox_path) as BattleHitbox2D
	assert(attack_hitbox != null and attack_hitbox.is_configuration_valid(), "2D 实体需要单一攻击判定框")
	hurtbox = get_node_or_null(hurtbox_path) as BattleHurtbox2D
	assert(hurtbox != null and hurtbox.is_configuration_valid(), "2D 实体需要独立的受击区域")
	feedback = get_node_or_null(^"CombatFeedback") as BattleCombatFeedback2D
	animation.action_completed.connect(_on_animation_completed)
	animation.play_action(&"idle")
	action_state.machine.state_changed.connect(_on_action_state_changed)
	action_state.bind(self)
	CoreSystem.event_bus.event_pushed.connect(_on_core_event)

func cleanup_battle() -> void:
	if _cleaned:
		return
	_cleaned = true
	_finish_attack(&"despawned")
	BattleGASBinding.cleanup(abilities, statuses)
	if action_state.machine.state_changed.is_connected(_on_action_state_changed):
		action_state.machine.state_changed.disconnect(_on_action_state_changed)
	action_state.dispose()
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
	if attack_instance != null and attack_instance.active:
		attack_instance.elapsed += delta
	abilities.advance_simulation(delta)
	_advance_attack_windows()
	statuses.advance_simulation(delta)
	attributes.advance_simulation(delta)
	var attack_active := combo.is_active() or (not _active_skill_id.is_empty() and abilities.get_ability_instance(_active_skill_id).is_active)
	# 意图决定行走状态，碰撞残余速度和技能位移不代表玩家持续走路。
	action_state.advance(delta, action_profile, not is_zero_approx(move_axis), running, motion.just_landed, attack_active)
	_advance_combo()
	_update_animation_command()
	_impact_display = maxf(0.0, _impact_display - delta)
	queue_redraw()
	if feedback != null:
		feedback.advance_feedback(delta)

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
	_begin_attack(id)
	var started_attack := attack_instance
	action_state.enter(BattleActionState2D.State.ATTACK, context.get("action_rules", {}))
	# Core 通知是同步的；进入状态时被打断不能覆盖受击/死亡动画。
	if attack_instance != started_attack or not started_attack.active or action_state.current != BattleActionState2D.State.ATTACK:
		return false
	animation.play_action(StringName(action_state.active_rules.get("animation", &"attack_1")), true)
	_publish_attack_started()
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
	_begin_attack(step.ability_id)
	var started_attack := attack_instance
	action_state.enter(BattleActionState2D.State.ATTACK, step.get_rules())
	if attack_instance != started_attack or not started_attack.active or action_state.current != BattleActionState2D.State.ATTACK:
		return false
	animation.play_action(step.action, true)
	_publish_attack_started()
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
	action_state.advance(0.0, action_profile, not is_zero_approx(move_axis), running)
	publish_battle_event(&"battle.combo.finished")

func receive_damage(amount: float, instigator: Node = null, interrupt_kind: StringName = &"normal", interrupt_priority: int = 60) -> float:
	if session.is_simulation_blocked() or not is_alive():
		return 0.0
	var info := DamageInfo.new(instigator, attributes, amount)
	info.final_damage = amount
	info.set_meta(&"interrupt_kind", interrupt_kind)
	info.set_meta(&"interrupt_priority", interrupt_priority)
	return (attributes.get_vital(&"health") as HealthVital).apply_damage(info, self)

func _cancel_abilities(reason: StringName = &"cancelled") -> void:
	_finish_attack(reason)
	combo.cancel()
	_active_skill_id = &""
	for id in abilities.get_all_ability_ids():
		abilities.get_ability_instance(id).end_ability()

func _on_vital_depleted(id: StringName) -> void:
	if id != &"health":
		return
	_cancel_abilities(&"death")
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
		_cancel_abilities(&"interrupted")
		action_state.enter(BattleActionState2D.State.HURT)
		if animation != null:
			animation.play_action(&"hurt", true)

func _on_animation_completed(action: StringName) -> void:
	## 只通知动作系统；此回调不改变战斗状态、生命或技能许可。
	publish_battle_event(&"battle.animation_completed", {"action": action})

func _on_action_state_changed(from_state: BaseState, to_state: BaseState) -> void:
	if animation != null and action_state.current in [BattleActionState2D.State.IDLE, BattleActionState2D.State.MOVE, BattleActionState2D.State.RUN]:
		_update_animation_command()
	publish_battle_event(&"battle.action_state_changed", {
		"from_state": from_state.state_id if from_state != null else &"",
		"to_state": to_state.state_id,
		"action_rules": action_state.active_rules.duplicate(true)
	})
#endregion
#region 原版攻击区域与 Core 事件
func get_attack_rect_local(context: Dictionary = {}) -> Rect2:
	var hitbox := _get_attack_hitbox(context)
	return hitbox.get_rect_local(self, animation.get_facing()) if hitbox != null else Rect2()

func _get_attack_hitbox(context: Dictionary) -> BattleHitbox2D:
	var ability: StringName = context.get("ability_id", _active_skill_id if not _active_skill_id.is_empty() else action_profile.attack_skill_id)
	var instance := abilities.get_ability_instance(ability)
	if attack_hitbox == null or instance == null:
		if attack_hitbox != null:
			attack_hitbox.clear_geometry()
		return null
	attack_hitbox.source_unit_scale = animation.profile.display_scale
	return attack_hitbox if attack_hitbox.configure_skill(instance.get_definition(), int(context.get("hit_index", 1))) else null

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
	if context.get("entity") != self or context.get("battle_id") != session.battle_id or not is_alive() or session.is_simulation_blocked():
		return
	if _active_skill_id.is_empty() or context.get("ability_id") != _active_skill_id or not abilities.get_ability_instance(_active_skill_id).is_active:
		return
	if attack_instance == null or not attack_instance.active or context.get("attack_id", &"") != attack_instance.attack_id:
		return
	last_impact_time = context.skill_time
	_impact_context = context.duplicate(true)
	_impact_display = 0.16
	var hitbox := _get_attack_hitbox(context)
	if hitbox == null:
		push_error("技能缺少有效的攻击判定数据：%s / hit %d" % [_active_skill_id, int(context.get("hit_index", 1))])
		return
	var definition := abilities.get_ability_instance(_active_skill_id).get_definition()
	var data := hitbox.find_impact_payload(definition, int(context.get("hit_index", 1)))
	var duration := maxf(0.0, float(data.get("hit_window_frames", 0))) / float(context.source_fps)
	if not attack_instance.open_window(context, duration):
		return
	publish_battle_event(&"battle.attack.window_opened", {"attack_id": attack_instance.attack_id, "hit_index": context.get("hit_index", 1), "duration": duration})
	_sample_attack_window(context)

func get_attack_instance() -> BattleAttackInstance:
	return attack_instance

func _begin_attack(id: StringName) -> void:
	_finish_attack(&"replaced")
	_attack_serial += 1
	attack_instance = BattleAttackInstance.new()
	attack_instance.initialize(self, id, _attack_serial)

func _publish_attack_started() -> void:
	var id := attack_instance.ability_id
	publish_battle_event(&"battle.attack.started", {"attack_id": attack_instance.attack_id, "ability_id": id})

func _finish_attack(reason: StringName) -> void:
	if attack_instance == null or not attack_instance.active:
		return
	attack_instance.close()
	publish_battle_event(&"battle.attack.finished", {"attack_id": attack_instance.attack_id, "ability_id": attack_instance.ability_id, "reason": reason, "hit_count": attack_instance.hit_targets.size()})

func _advance_attack_windows() -> void:
	if attack_instance == null or not attack_instance.active:
		return
	var skill := abilities.get_ability_instance(attack_instance.ability_id)
	if not is_alive() or skill == null or not skill.is_active:
		_finish_attack(&"completed")
		if not combo.is_active():
			_active_skill_id = &""
		return
	for index in attack_instance.windows.keys():
		if not attack_instance.active:
			return
		var context: Dictionary = attack_instance.windows.get(index, {})
		if context.is_empty():
			continue
		if attack_instance.elapsed + 0.000000001 < float(context.window_end):
			_sample_attack_window(context)

func _sample_attack_window(context: Dictionary) -> void:
	var current_attack := attack_instance
	var hitbox := _get_attack_hitbox(context)
	if hitbox == null:
		return
	for target in session.get_entities():
		if not current_attack.active or current_attack != attack_instance or not is_alive() or session.is_simulation_blocked():
			break
		if not target is BattleEntity2D or target == self or not target.is_alive() or target.is_queued_for_deletion():
			continue
		if not session.factions.is_hostile(current_attack.faction_id, target.faction_id) or not hitbox.intersects_hurtbox(self, animation.get_facing(), target.hurtbox):
			continue
		if not current_attack.register_hit(int(context.get("hit_index", 1)), target.entity_id):
			continue
		var calculated := DamageCalculator.calculate_final_damage(target, self, context)
		var previous: float = target.attributes.get_vital_value(&"health")
		var resolved: float = target.receive_damage(calculated, self)
		var damage: float = previous - target.attributes.get_vital_value(&"health")
		session.publish_event(&"battle.attack.hit", self, target, {"attack_id": current_attack.attack_id, "damage": damage, "calculated_damage": calculated, "resolved_damage": resolved, "skill_time": context.skill_time, "source_frame": context.source_frame, "combo_step": context.get("combo_step", 0), "hit_index": context.get("hit_index", 1), "ability_id": context.ability_id})

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
		var hitbox := _get_attack_hitbox(_impact_context)
		if hitbox != null:
			var polygon := hitbox.get_polygon_local(self, animation.get_facing())
			draw_colored_polygon(polygon, Color(1, 0.65, 0.15, 0.16))
			var outline := polygon.duplicate()
			outline.append(polygon[0])
			draw_polyline(outline, Color("ffd080"), 2)
	for socket in [&"weapon", &"weapon_alt", &"weapon_long"]:
		if not animation.is_socket_active(socket):
			continue
		var point := to_local(animation.get_socket_global_transform(socket).origin)
		draw_circle(point, 3, Color("ffd080"))
#endregion
