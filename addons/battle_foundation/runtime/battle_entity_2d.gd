extends CharacterBody2D
class_name BattleEntity2D
#region 实体与战斗状态
@export var action_profile: BattleActionProfile2D
@export var animation_path: NodePath = ^"AnimationAdapter"
@export var attack_hitbox_path: NodePath = ^"AnimationAdapter/AttackHitbox"
@export var hurtbox_path: NodePath = ^"Hurtbox"
@export var show_registration: bool = true
## 怪物播放一次死亡动作后隐藏并停止运动；关卡出生统计仍保留实体ID。
@export var hide_after_death: bool = false
var _death_visual_remaining: float = 0.0
@export_group("Hit Reaction / Protection")
@export var reaction_profile: BattleHitReactionProfile = BattleHitReactionProfile.new()
## 留空不启用保护条，保留阶段6—8的独立示例。
@export var protection_profile: BattleProtectionProfile
@export_group("Scene Registration")
@export var scene_definition_id: StringName = &""
@export_enum("characters", "monsters") var scene_category: String = "characters"
@export var scene_session_path: NodePath = ^"../.."
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
## 兼容查询入口：视图归战斗场景所有，角色不持有、不推进公共表现。
var feedback: BattleCombatFeedback2D:
	get:
		return session.presentation.get_feedback(self) if is_instance_valid(session) and is_instance_valid(session.presentation) else null
var action_state: BattleActionState2D
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
var wushuang: BattleWushuangController
var operations: BattlePlayerOperations
var ai_controller: BattleAIController2D
var skill_aim_axis: float = 0.0
var motion: BattleMotionController2D
var combo: BattleComboState
var super_armor: bool = false
var _active_skill_id: StringName = &""
var _impact_context: Dictionary = {}
## 兼容旧固定增量监控，不作为当前保护条；当前条查询 protection.score。
var received_protection: float = 0.0
var reactions: BattleHitReactionController2D
var protection: BattleProtectionSystem
var _pending_derived_skill: Dictionary = {}
var damage_rules: BattleDamageRules
var inventory: C_Inventory
## 可设置固定随机输入/技能等级；每个实体独立，时间轴参数优先。
@export var damage_context: Dictionary = {}
var spawn_remaining: float = 0.0
var _spawn_collision_layer: int = 0
var _spawn_collision_mask: int = 0
var _spawning: bool = false
var _spawn_animation_visible: bool = true
#endregion
#region 初始化与清理
func get_component_configuration_error(data: BattleEntityDefinition = null) -> String:
	var error := BattleGASBinding.get_configuration_error(self, data)
	if not error.is_empty():
		return error
	for spec in [[^"ActionState", BattleActionState2D], [^"MotionController", BattleMotionController2D], [^"ComboState", BattleComboState], [^"HitReactionController", BattleHitReactionController2D], [^"ProtectionSystem", BattleProtectionSystem]]:
		if not is_instance_of(get_node_or_null(spec[0]), spec[1]):
			return "2D 实体场景缺少或类型错误的预置组件：" + str(spec[0])
	var input := get_node_or_null(^"PlayerOperations") as BattlePlayerOperations
	if input != null and not input.get_node_or_null(input.controller_path) is CoreOperationController:
		return "角色场景必须预置 PlayerOperations/OperationController"
	var ai := get_node_or_null(^"AIController")
	if ai != null and (not ai is BattleAIController2D or ai.profile == null or not ai.profile.is_valid()):
		return "AIController必须使用BattleAIController2D和有效的AI配置"
	if ai is BattleBossController2D and (ai.boss_profile == null or not ai.boss_profile.is_valid() or not get_node_or_null(^"BossObjects") is BattleBossObjectPool2D):
		return "Boss必须预置有效行为配置和完整时间轴对象池"
	return ""

func _bind_scene_components() -> void:
	assert(get_component_configuration_error().is_empty(), get_component_configuration_error())
	action_state = get_node(^"ActionState") as BattleActionState2D
	motion = get_node(^"MotionController") as BattleMotionController2D
	combo = get_node(^"ComboState") as BattleComboState
	reactions = get_node(^"HitReactionController") as BattleHitReactionController2D
	protection = get_node(^"ProtectionSystem") as BattleProtectionSystem
	damage_rules = (get_node(^"DamageRules") as BattleDamageRulesComponent).rules
	inventory = get_node_or_null(^"Inventory") as C_Inventory
	operations = get_node_or_null(^"PlayerOperations") as BattlePlayerOperations
	ai_controller = get_node_or_null(^"AIController") as BattleAIController2D
	wushuang = get_node_or_null(^"WushuangController") as BattleWushuangController

func _enter_tree() -> void:
	if entity_id.is_empty() and not scene_definition_id.is_empty():
		var owner_session := get_node_or_null(scene_session_path) as BattleSession
		assert(owner_session != null, "预置实体需要有效的 BattleSession 路径")
		var registered := owner_session.register_scene_entity_2d(self, scene_category, scene_definition_id)
		assert(registered, owner_session.last_error)

func initialize_battle(owner_session: BattleSession, id: StringName, data: BattleEntityDefinition) -> void:
	assert(entity_id.is_empty(), "战斗实体不能重复初始化")
	_bind_scene_components()
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
	_bind_scene_components()
	motion.body = self
	if wushuang != null: wushuang.bind(self)
	assert(reaction_profile != null and reaction_profile.is_valid(), "目标受击反应配置无效")
	reactions.bind(self)
	assert(protection.configure(self, protection_profile), protection.last_error)
	combo.definition = action_profile.combo
	assert(combo.definition == null or combo.definition.is_valid(), "连击定义无效")
	animation = get_node_or_null(animation_path) as CharacterAnimationAdapter
	assert(animation != null and action_profile != null, "2D 实体需要独立动画层和动作规则配置")
	attack_hitbox = get_node_or_null(attack_hitbox_path) as BattleHitbox2D
	assert(attack_hitbox != null and attack_hitbox.is_configuration_valid(), "2D 实体需要单一攻击判定框")
	hurtbox = get_node_or_null(hurtbox_path) as BattleHurtbox2D
	assert(hurtbox != null and hurtbox.is_configuration_valid(), "2D 实体需要独立的受击区域")
	animation.action_completed.connect(_on_animation_completed)
	animation.play_action(&"idle")
	action_state.machine.state_changed.connect(_on_action_state_changed)
	action_state.bind(self)
	statuses.status_applied.connect(func(_id, _instance): _sync_status_control())
	statuses.status_removed.connect(func(_id): _sync_status_control())
	_sync_status_control()
	if ai_controller != null:
		ai_controller.bind(self)
	if inventory != null:
		attributes.bind_inventory(inventory)
		if inventory is OriginalInventory:
			inventory.appearance_changed.connect(_on_inventory_appearance_changed)
		else:
			inventory.equip_changed.connect(_on_equipment_appearance_changed)
	CoreSystem.event_bus.event_pushed.connect(_on_core_event)
	if session.presentation != null:
		session.presentation.register_actor(self)

func _on_equipment_appearance_changed(slot: StringName, item: Equip) -> void:
	if inventory is OriginalInventory:
		_on_inventory_appearance_changed()
		return
	if not animation is SpineAnimationAdapter or slot not in [&"armor", &"helmet", &"weapon"]: return
	var skin: StringName = item.appearance_skin if item is BattleInventoryEquipment else &""
	if not skin.is_empty() and not animation.get_available_skins().has(skin): return
	animation.set_equipment_skin(slot, skin)

func _on_inventory_appearance_changed() -> void:
	if not inventory is OriginalInventory or not animation is SpineAnimationAdapter: return
	for part: StringName in [&"armor", &"helmet", &"weapon"]:
		var skin: StringName = inventory.get_equipment_appearance(part)
		if not skin.is_empty() and not animation.get_available_skins().has(skin): continue
		animation.set_equipment_skin(part, skin)

func cleanup_battle() -> void:
	if _cleaned:
		return
	_cleaned = true
	_finish_spawn_appearance()
	if ai_controller != null and ai_controller.has_method("cleanup_boss"): ai_controller.cleanup_boss()
	_finish_attack(&"despawned")
	if wushuang != null: wushuang.clear()
	BattleGASBinding.cleanup(abilities, statuses)
	if animation != null: animation.clear_status_visuals()
	damage_rules.clear()
	protection.clear()
	if action_state.machine.state_changed.is_connected(_on_action_state_changed):
		action_state.machine.state_changed.disconnect(_on_action_state_changed)
	action_state.dispose()
	if CoreSystem.event_bus.event_pushed.is_connected(_on_core_event):
		CoreSystem.event_bus.event_pushed.disconnect(_on_core_event)

func _exit_tree() -> void:
	cleanup_battle()
#endregion
#region 固定物理与动画时间
## 关卡刷怪/召唤在完整节点初始化后调用；原版showAppear=0直接开始。
func begin_spawn_appearance(kind: int) -> bool:
	if _spawning or _cleaned or not is_alive() or feedback == null: return false
	var duration := feedback.appearance.play_appearance(kind)
	if duration <= 0: return false
	_spawning = true
	spawn_remaining = duration
	_spawn_collision_layer = collision_layer
	_spawn_collision_mask = collision_mask
	_spawn_animation_visible = animation.visible
	animation.visible = false
	collision_layer = 0
	collision_mask = 0
	return true

func is_spawning() -> bool:
	return _spawning

func _finish_spawn_appearance() -> void:
	if not _spawning: return
	_spawning = false
	spawn_remaining = 0
	if feedback != null: feedback.appearance.clear_effect()
	if is_instance_valid(animation): animation.visible = _spawn_animation_visible
	collision_layer = _spawn_collision_layer
	collision_mask = _spawn_collision_mask

func advance_input(unscaled_delta: float) -> void:
	if is_instance_valid(operations):
		operations.advance_input(unscaled_delta)

func advance_simulation(delta: float) -> void:
	if delta <= 0.0 or animation == null:
		return
	if hide_after_death and not is_alive():
		if ai_controller != null: ai_controller.advance_simulation(delta)
		if _death_visual_remaining > 0:
			_death_visual_remaining = maxf(0, _death_visual_remaining - delta)
			animation.advance_animation(delta)
		if _death_visual_remaining <= 0:
			hide()
			collision_layer = 0
			collision_mask = 0
			if feedback != null: feedback.hide()
		return
	if spawn_remaining > 0:
		if not is_alive(): _finish_spawn_appearance()
		else:
			var used := minf(delta, spawn_remaining)
			if feedback != null: feedback.appearance.advance_effect(used)
			spawn_remaining = maxf(0, spawn_remaining-used)
			delta -= used
			if spawn_remaining <= 0: _finish_spawn_appearance()
			if delta <= 0: return
	protection.advance(delta)
	if is_instance_valid(ai_controller):
		ai_controller.advance_simulation(delta)
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
		horizontal += step.root_motion_speed * combo.motion_facing * active_delta / delta
	motion.advance(delta, horizontal, action_profile, float(action_state.active_rules.get("gravity_scale", 1.0)))
	action_state.grounded = motion.grounded
	if action_state.current == BattleActionState2D.State.JUMP_ATTACK and motion.just_landed:
		_cancel_abilities(&"landed")
		action_state.enter(BattleActionState2D.State.LAND)
	elif action_state.current == BattleActionState2D.State.RUN_ATTACK and not motion.grounded:
		_cancel_abilities(&"left_ground")
		action_state.enter(BattleActionState2D.State.JUMP)
	if combo.is_active() and not motion.grounded:
		_cancel_abilities()
		action_state.enter(BattleActionState2D.State.JUMP)
	if motion.just_landed:
		publish_battle_event(&"battle.motion.landed", {"landing_serial": motion.landing_serial})
	## 本 tick 先更新世界位置和姿态，再让 GAS 发送素材帧攻击事件。
	if attack_instance == null or not attack_instance.active or attack_instance.timeline == null or not attack_instance.timeline.uses_cast_timeline():
		animation.advance_animation(delta)
	if attack_instance != null and attack_instance.active and (attack_instance.timeline == null or not attack_instance.timeline.uses_cast_timeline()):
		attack_instance.elapsed += delta
	abilities.advance_simulation(delta)
	if ai_controller != null and ai_controller.has_method("advance_post_simulation"): ai_controller.advance_post_simulation(delta)
	_advance_attack_windows()
	if attack_instance != null and attack_instance.active:
		attack_instance.advance_objects(delta)
	if wushuang != null: wushuang.advance_simulation(delta)
	statuses.advance_simulation(delta)
	attributes.advance_simulation(delta)
	var active_skill := abilities.get_ability_instance(_active_skill_id) if not _active_skill_id.is_empty() else null
	var attack_active := combo.is_active() or (active_skill != null and active_skill.is_active)
	# 意图决定行走状态，碰撞残余速度和技能位移不代表玩家持续走路。
	action_state.advance(delta, action_profile, not is_zero_approx(move_axis), running, motion.just_landed, attack_active)
	_advance_combo()
	_update_animation_command()
	animation.advance_status_visuals(delta)
	protection.refresh_visual()
	_impact_display = maxf(0.0, _impact_display - delta)
	queue_redraw()
	if not _pending_derived_skill.is_empty():
		var next := _pending_derived_skill.duplicate(true)
		_pending_derived_skill.clear()
		try_activate_skill(next.id, next.context)

func _update_animation_command() -> void:
	var action: StringName = &"idle"
	match action_state.current:
		BattleActionState2D.State.MOVE: action = &"move"
		BattleActionState2D.State.RUN: action = &"run"
		BattleActionState2D.State.TAKEOFF, BattleActionState2D.State.JUMP: action = &"fall" if velocity.y > 0.0 else (&"jump_2" if motion.jump_count >= 2 else &"jump")
		BattleActionState2D.State.LAND: action = &"land"
		BattleActionState2D.State.ATTACK, BattleActionState2D.State.RUN_ATTACK, BattleActionState2D.State.JUMP_ATTACK: action = combo.get_step().action if combo.is_active() else StringName(action_state.active_rules.get("animation", &"attack_1"))
		BattleActionState2D.State.HURT, BattleActionState2D.State.STUN: action = &"hurt"
		BattleActionState2D.State.LAUNCHED: action = &"launched"
		BattleActionState2D.State.AIR_HURT: action = &"air_hurt"
		BattleActionState2D.State.HIT_LAND: action = &"hit_land"
		BattleActionState2D.State.KNOCKDOWN: action = &"knockdown"
		BattleActionState2D.State.GETUP: action = &"getup"
		BattleActionState2D.State.PROTECT: action = &"protect"
		BattleActionState2D.State.DEAD: action = &"death"
	# 未提供专用空中/倒地素材的角色仍有明确表现回退，不能静默保留攻击动画。
	if animation.get_action_duration(action) <= 0.0:
		action = &"idle" if action in [&"getup", &"protect"] else &"hurt"
	animation.play_action(action)

func refresh_action_animation(restart: bool = false) -> void:
	_update_animation_command()
	if restart:
		animation.play_action(animation.get_current_action(), true)
#endregion
#region 战斗命令
func is_alive() -> bool:
	return attributes.get_vital_value(&"health") > 0.0 and action_state.current != BattleActionState2D.State.DEAD

func try_attack() -> bool:
	if session.is_simulation_blocked() or is_spawning() or not is_alive():
		return false
	if not motion.grounded and action_state.current in [BattleActionState2D.State.TAKEOFF, BattleActionState2D.State.JUMP]:
		return try_activate_skill(action_profile.jump_attack_skill_id) if not action_profile.jump_attack_skill_id.is_empty() else false
	if action_state.current == BattleActionState2D.State.RUN and not action_profile.run_attack_skill_id.is_empty():
		return try_activate_skill(action_profile.run_attack_skill_id)
	if not action_state.can_attack(true):
		return false
	return _start_combo_step(0) if combo.definition != null else try_activate_skill(action_profile.attack_skill_id)

func request_attack() -> bool:
	if session.is_simulation_blocked() or is_spawning() or not is_alive():
		return false
	if action_state.current == BattleActionState2D.State.ATTACK and combo.is_active():
		return combo.queue_next()
	if _is_attack_state() and attack_instance != null:
		return attack_instance.buffer_operation(&"attack")
	return try_attack()

func cancel_operation_commands() -> void:
	combo.queued_next = false
	if attack_instance != null:
		attack_instance.buffered_operations.clear()

func try_jump() -> bool:
	if session.is_simulation_blocked() or is_spawning() or not action_state.can_jump(is_alive(), action_profile) or not motion.can_jump(action_profile.maximum_jumps):
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
	if session.is_simulation_blocked() or is_spawning() or not is_alive() or not abilities.has_ability(id):
		return false
	# 无动作状态技能（包括无双）无需进入攻击动作，保留当前连击/移动和技能时间轴。
	if abilities.get_ability_instance(id).get_feature("BattleStatusActivationFeature") != null:
		return abilities.can_activate_ability(id, context) and abilities.try_activate_ability(id, context)
	if combo.definition != null:
		for index in range(combo.definition.steps.size()):
			if combo.definition.steps[index].ability_id == id:
				return _start_combo_step(index, false, context)
	var target_state := BattleActionState2D.State.ATTACK
	var timeline := abilities.get_ability_instance(id).get_feature("BattleFrameTimelineFeature") as BattleFrameTimelineFeature
	if id == action_profile.jump_attack_skill_id:
		if motion.grounded or action_state.current not in [BattleActionState2D.State.TAKEOFF, BattleActionState2D.State.JUMP]:
			return false
		target_state = BattleActionState2D.State.JUMP_ATTACK
	elif id == action_profile.run_attack_skill_id:
		if not motion.grounded or action_state.current != BattleActionState2D.State.RUN:
			return false
		target_state = BattleActionState2D.State.RUN_ATTACK
	else:
		var free_state := action_state.current in [BattleActionState2D.State.IDLE, BattleActionState2D.State.MOVE, BattleActionState2D.State.RUN, BattleActionState2D.State.LAND, BattleActionState2D.State.TAKEOFF, BattleActionState2D.State.JUMP]
		var can_interrupt := _is_attack_state() and timeline != null and timeline.interrupt_actions.has(animation.get_current_action())
		var location_allowed := (timeline == null or timeline.can_use_on_ground) if motion.grounded else (timeline != null and timeline.can_use_in_air)
		# 只有已通过派生窗口校验的子技能能继承原释放地点。
		if context.has("derived_from"):
			location_allowed = true
		if not location_allowed or (not free_state and not can_interrupt):
			return false
	context = context.duplicate(true)
	context["skill_level"] = BattleSkillLevelValues.get_level(self, id, context)
	if not abilities.can_activate_ability(id, context):
		return false
	if _is_attack_state():
		_cancel_abilities(&"skill_interrupt")
	if action_state.get_permission(&"turn", action_profile) and not is_zero_approx(move_axis):
		animation.set_facing(1 if move_axis > 0.0 else -1)
	if not abilities.can_activate_ability(id, context) or not abilities.try_activate_ability(id, context):
		return false
	if not abilities.get_ability_instance(id).is_active or not is_alive():
		return false
	_active_skill_id = id
	_begin_attack(id)
	var started_attack := attack_instance
	started_attack.initiating_operation = StringName(context.get("operation", &""))
	var rules: Dictionary = context.get("action_rules", {}).duplicate(true)
	if started_attack.timeline != null:
		rules = started_attack.timeline.action_rules.duplicate(true)
		rules.merge(context.get("action_rules", {}), true)
		rules["animation"] = started_attack.timeline.animation_action
	action_state.enter(target_state, rules)
	if is_zero_approx(float(rules.get("gravity_scale", 1.0))):
		velocity.y = 0.0
	# Core 通知是同步的；进入状态时被打断不能覆盖受击/死亡动画。
	if attack_instance != started_attack or not started_attack.active or action_state.current != target_state:
		return false
	animation.play_action(StringName(action_state.active_rules.get("animation", &"attack_1")), true)
	_publish_attack_started()
	return true

func _start_combo_step(index: int, continuing: bool = false, context: Dictionary = {}) -> bool:
	if combo.definition == null or index < 0 or index >= combo.definition.steps.size():
		return false
	if session.is_simulation_blocked() or is_spawning() or not is_alive() or not motion.grounded or (not continuing and not action_state.can_attack(true)):
		return false
	var step: BattleAttackStep2D = combo.definition.steps[index]
	if not abilities.has_ability(step.ability_id) or not abilities.can_activate_ability(step.ability_id, context):
		return false
	var activation_context := context.duplicate(true)
	activation_context["combo_step"] = index + 1
	if not abilities.try_activate_ability(step.ability_id, activation_context):
		return false
	if not abilities.get_ability_instance(step.ability_id).is_active or not is_alive():
		return false
	combo.begin(index, animation.get_facing())
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

func _is_attack_state() -> bool:
	return action_state.current in [BattleActionState2D.State.ATTACK, BattleActionState2D.State.RUN_ATTACK, BattleActionState2D.State.JUMP_ATTACK]

func try_turn_combo(direction: int) -> bool:
	if session.is_simulation_blocked() or is_spawning() or not is_alive() or action_state.current != BattleActionState2D.State.ATTACK or not combo.is_active() or combo.turn_used:
		return false
	var step := combo.get_step()
	if direction == 0 or direction == animation.get_facing() or attack_instance == null or not attack_instance.active or not step.contains_turn_time(attack_instance.elapsed):
		return false
	combo.turn_used = true
	animation.set_facing(direction)
	attack_instance.facing = animation.get_facing()
	# 不重启动画、不重置已命中记录、不改motion_facing或当前velocity。
	publish_battle_event(&"battle.combo.turned", {"combo_step": combo.index + 1, "attack_id": attack_instance.attack_id, "facing": attack_instance.facing, "motion_facing": combo.motion_facing, "source_frame": attack_instance.elapsed * step.source_fps})
	return true

func _advance_combo() -> void:
	if not combo.is_active():
		return
	var skill := abilities.get_ability_instance(combo.get_step().ability_id)
	if skill != null and skill.is_active:
		return
	var next := combo.index + 1
	var queued := combo.queued_next
	combo.cancel()
	_active_skill_id = &""
	if queued and _start_combo_step(next, true):
		return
	action_state.advance(0.0, action_profile, not is_zero_approx(move_axis), running)
	publish_battle_event(&"battle.combo.finished")

func receive_damage(amount: float, instigator: Node = null, interrupt_kind: StringName = &"normal", interrupt_priority: int = 60, hit_context: Dictionary = {}) -> float:
	var info := DamageInfo.new(instigator, attributes, amount)
	info.final_damage = amount
	info.calculated_damage = amount
	info.normal_damage = amount
	return receive_damage_info(info, interrupt_kind, interrupt_priority, hit_context)

func receive_damage_info(info: DamageInfo, interrupt_kind: StringName = &"normal", interrupt_priority: int = 60, hit_context: Dictionary = {}) -> float:
	if session.is_simulation_blocked() or is_spawning() or not is_alive():
		return 0.0
	if info.applied and info.single_use:
		return info.actual_hp_loss
	info.set_meta(&"interrupt_kind", interrupt_kind)
	info.set_meta(&"interrupt_priority", interrupt_priority)
	info.set_meta(&"hit_context", hit_context.duplicate(true))
	info.set_meta(&"reaction_deferred", true)
	var policy := reactions.get_policy(self)
	if not policy.damage and not bool(hit_context.get("bypass_damage_policy", false)):
		# 真正的无敌在 Vital 前截断；不消耗护盾、不吸血，也不运行伤害 Buff。
		info.applied = true
		info.is_immune = true
		info.final_damage = 0.0
		info.normal_damage = 0.0
		info.true_damage = 0.0
		info.actual_hp_loss = 0.0
		info.hp_before = attributes.get_vital_value(&"health")
		info.hp_after = info.hp_before
	else:
		info.set_meta(&"battle_received_damage_multiplier", reaction_profile.armor_damage_multiplier if reactions.is_armored(self) and not bool(hit_context.get("bypass_armor_multiplier", false)) else 1.0)
		(attributes.get_vital(&"health") as HealthVital).apply_damage(info, self)
	var effects := {"reaction_applied": false, "displacement_applied": false, "protection_increment": 0}
	if not info.is_dodged and bool(hit_context.get("apply_hit_reaction", true)):
		if is_alive():
			if policy.status:
				for status_id in hit_context.get("status_ids", []):
					apply_status_definition(StringName(status_id), info.instigator)
			if info.actual_hp_loss > 0.0:
				received_protection += float(hit_context.get("protection_value", 0.0))
			if policy.protection:
				var multiplier := 1.0
				if info.instigator is BattleEntity2D:
					multiplier = info.instigator.damage_rules.get_number(&"protectionMultiplier", 1.0)
				var protect_result := protection.register_hit(hit_context, info.actual_hp_loss, attributes.get_value(&"hpMax"), multiplier)
				effects["protection_increment"] = protect_result.increment
			# 触发保护的本次命中不能再用普通硬直覆盖 PROTECT。
			policy = reactions.get_policy(self)
			effects.merge(reactions.resolve(info, hit_context, interrupt_kind, interrupt_priority, policy), true)
		if policy.hit_stop:
			session.request_hit_stop(maxf(0.0, float(hit_context.get("hit_stop_seconds", 0.0))))
	info.set_meta(&"hit_effects", effects)
	if info.applied:
		session.publish_damage_result(info, self, hit_context)
	cleanup_death_statuses()
	return info.actual_hp_loss

func _cancel_abilities(reason: StringName = &"cancelled") -> void:
	_pending_derived_skill.clear()
	_finish_attack(reason)
	combo.cancel()
	_active_skill_id = &""
	for id in abilities.get_all_ability_ids():
		abilities.get_ability_instance(id).end_ability()

func _on_vital_depleted(id: StringName) -> void:
	if id == &"health": _finish_spawn_appearance()
	if id != &"health":
		return
	if action_state.current == BattleActionState2D.State.DEAD: return
	if wushuang != null: wushuang.clear()
	_cancel_abilities(&"death")
	action_state.enter(BattleActionState2D.State.DEAD)
	move_axis = 0.0
	velocity.x = 0.0
	motion.clear_impulse()
	protection.clear()
	if is_instance_valid(operations):
		operations.set_control_blocked(&"dead", true)
	if animation != null:
		animation.play_action(&"death", true)
		_death_visual_remaining = maxf(0.0, animation.get_action_duration(&"death"))
	publish_battle_event(&"battle.entity_died")
	# Fatal hit仍完成受击/击杀触发；直接修改Vital的死亡由延迟入口兜底。
	call_deferred(&"cleanup_death_statuses")

func _on_damage_applied(info: DamageInfo, _damage: float) -> void:
	# 统一命中入口稍后独立裁决；兼容直接通过 GAS Vital 扣血的外部效果。
	if not bool(info.get_meta(&"reaction_deferred", false)) and is_alive():
		reactions.resolve(info, info.get_meta(&"hit_context", {}), StringName(info.get_meta(&"interrupt_kind", &"normal")), int(info.get_meta(&"interrupt_priority", 60)), reactions.get_policy(self))

func _on_animation_completed(action: StringName) -> void:
	## 只通知动作系统；此回调不改变战斗状态、生命或技能许可。
	publish_battle_event(&"battle.animation_completed", {"action": action})

func _on_action_state_changed(from_state: BaseState, to_state: BaseState) -> void:
	if animation != null:
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
	var frame := float(context.get("sample_time", context.get("skill_time", 0.0))) * float(context.get("source_fps", action_profile.source_fps))
	var index := int(context.get("hit_index", 1))
	var overrides := {}
	if attack_instance != null and attack_instance.active and attack_instance.timeline != null and attack_instance.timeline.aim_segment_index == index:
		overrides["hit_rotation"] = deg_to_rad(attack_instance.aim_degrees)
	return attack_hitbox if attack_hitbox.configure_skill(instance.get_definition(), index, frame, overrides) else null

func get_attack_rect_global(context: Dictionary = {}) -> Rect2:
	return global_transform * get_attack_rect_local(context)

func get_attack_position() -> Vector2:
	return to_global(get_attack_rect_local().get_center())

func get_body_rect_global() -> Rect2:
	var collision := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	return collision.global_transform * collision.shape.get_rect() if collision != null else Rect2(global_position, Vector2.ZERO)

func _on_core_event(event_id: String, payload: Array) -> void:
	if event_id not in ["battle.attack.impact", "battle.skill.object", "battle.skill.animation"] or payload.size() != 1 or not payload[0] is Dictionary:
		return
	var context: Dictionary = payload[0]
	if context.get("entity") != self or context.get("battle_id") != session.battle_id or not is_alive() or session.is_simulation_blocked():
		return
	if _active_skill_id.is_empty() or context.get("ability_id") != _active_skill_id or not abilities.get_ability_instance(_active_skill_id).is_active:
		return
	if attack_instance == null or not attack_instance.active or context.get("attack_id", &"") != attack_instance.attack_id:
		return
	if event_id == "battle.skill.animation":
		var rules := action_state.active_rules.duplicate(true)
		rules["animation"] = StringName(context.get("action", &"attack_1"))
		action_state.active_rules = rules
		animation.play_action(rules.animation, true)
		return
	if event_id == "battle.skill.object":
		var object := get_node_or_null(NodePath(context.get("object_path", ""))) as BattleTimelineObject2D
		if object == null:
			push_error("时间轴对象必须预置在角色场景：%s" % context.get("object_path", ""))
			return
		object.activate_cast(attack_instance, context, self)
		publish_battle_event(&"battle.skill.object_spawned", {"attack_id": attack_instance.attack_id, "object_kind": object.object_kind, "object_path": context.object_path, "skill_time": context.skill_time})
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
	var window_context := context.duplicate(true)
	window_context["skill_time"] = float(context.get("window_start", context.skill_time))
	var opened := attack_instance.open_window(window_context, duration)
	if not opened and not bool(context.get("timeline_sample", false)):
		return
	if opened:
		publish_battle_event(&"battle.attack.window_opened", {"attack_id": attack_instance.attack_id, "hit_index": context.get("hit_index", 1), "duration": duration})
	if not attack_instance.active or attack_instance.attack_id != context.get("attack_id", &""):
		return
	_sample_attack_window(context)
	if duration <= 0.0:
		attack_instance.windows.erase(int(context.get("hit_index", 1)))

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
	if reason == &"completed" and action_state.current == BattleActionState2D.State.RUN_ATTACK:
		# 跑攻结束回待机，旧方向/Shift/双击不能让下一帧自动恢复奔跑。
		if is_instance_valid(operations): operations.finish_run_attack()
		move_axis = 0.0
		running = false
		action_state.enter(BattleActionState2D.State.IDLE if motion.grounded else BattleActionState2D.State.JUMP)
	_impact_display = 0.0
	_impact_context.clear()
	if attack_hitbox != null:
		attack_hitbox.clear_geometry()
	publish_battle_event(&"battle.attack.finished", {"attack_id": attack_instance.attack_id, "ability_id": attack_instance.ability_id, "reason": reason, "hit_count": attack_instance.hit_count})

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
			var sample := context.duplicate(true)
			sample["sample_time"] = attack_instance.elapsed
			_sample_attack_window(sample)
		else:
			attack_instance.windows.erase(index)

func _sample_attack_window(context: Dictionary) -> void:
	var current_attack := attack_instance
	if current_attack == null or not current_attack.active:
		return
	var hitbox := _get_attack_hitbox(context)
	if hitbox == null:
		return
	for target in session.get_entities():
		if not current_attack.active or current_attack != attack_instance or not is_alive() or session.is_simulation_blocked():
			break
		if not target is BattleEntity2D or target == self or not target.is_alive() or target.is_spawning() or target.is_queued_for_deletion():
			continue
		if not session.factions.is_hostile(current_attack.faction_id, target.faction_id) or not hitbox.intersects_hurtbox(self, animation.get_facing(), target.hurtbox):
			continue
		if not current_attack.register_hit(int(context.get("hit_index", 1)), target.entity_id, context):
			continue
		var hit_context := context.duplicate(true)
		hit_context.merge({"attack_facing": current_attack.facing, "attack_id": current_attack.attack_id, "sample_time": context.get("sample_time", current_attack.elapsed), "target_hit_count": current_attack.hit_targets["%d/%s" % [int(context.get("hit_index", 1)), target.entity_id]].count}, true)
		resolve_attack_hit(target, hit_context)

## 身体攻击与独立弹道/场景对象共用GAS、受击、保护、被动及反馈入口。
func resolve_attack_hit(target: BattleEntity2D, context: Dictionary) -> Dictionary:
	if not is_alive() or is_spawning() or not is_instance_valid(target) or not target.is_alive() or target.is_spawning() or session.is_simulation_blocked(): return {}
	var hit_context := context.duplicate(true)
	hit_context["defer_attack_feedback"] = true
	var calculation_context := damage_context.duplicate(true)
	calculation_context.merge(hit_context, true)
	var rage_cast := attack_instance
	var info := DamageCalculator.calculate_damage(target, self, calculation_context)
	var damage: float = target.receive_damage_info(info, StringName(context.get("interrupt_kind", &"normal")), int(context.get("interrupt_priority", 60)), hit_context)
	BattleWushuangController.register_attack_hit(self, target, rage_cast, info, hit_context)
	var result := hit_context.duplicate(true)
	result.merge(info.to_dictionary(), true)
	result.merge(info.get_meta(&"hit_effects", {}), true)
	result["damage"] = damage
	session.publish_event(&"battle.attack.hit", self, target, result)
	return result

#endregion
#region 时间轴取消与操作派生入口
func advance_timeline_motion(cast: BattleAttackInstance, until: float) -> void:
	if attack_instance != cast or not cast.active:
		return
	var displacement := cast.get_motion_between(cast.elapsed, until)
	var previous_elapsed := cast.elapsed
	var animation_delta := maxf(0.0, until - cast.elapsed)
	var landing_serial := motion.landing_serial
	motion.sweep_skill_displacement(displacement, action_profile)
	action_state.grounded = motion.grounded
	if action_state.current == BattleActionState2D.State.RUN_ATTACK and not motion.grounded:
		_cancel_abilities(&"left_ground")
		action_state.enter(BattleActionState2D.State.JUMP)
		return
	cast.elapsed = until
	animation.advance_animation(animation_delta)
	if cast.timeline != null and cast.timeline.aim_segment_index > 0:
		var aim_delta := 0.0
		var aiming := false
		for segment in cast.timeline.attack_segments:
			if segment.hit_index == cast.timeline.aim_segment_index:
				var start := segment.start_frame / cast.timeline.source_fps
				var end := segment.end_frame / cast.timeline.source_fps
				aim_delta = maxf(0.0, minf(until,end)-maxf(previous_elapsed,start))
				aiming = until + 0.000000001 >= start and until + 0.000000001 < end
				break
		cast.aim_degrees = clampf(cast.aim_degrees + skill_aim_axis * cast.timeline.aim_speed_degrees * aim_delta, cast.timeline.aim_min_degrees, cast.timeline.aim_max_degrees)
		if aiming and animation is SpineAnimationAdapter:
			animation.apply_skill_aim(cast.timeline, cast.aim_degrees)
	if motion.landing_serial != landing_serial:
		publish_battle_event(&"battle.motion.landed", {"landing_serial": motion.landing_serial})

func cancel_skill(reason: StringName = &"cancelled") -> void:
	if animation is SpineAnimationAdapter:
		animation.clear_effect_tail()
	_cancel_abilities(reason)
	if _is_attack_state():
		action_state.advance(0.0, action_profile, not is_zero_approx(move_axis), running)
		_update_animation_command()

func finish_timeline_cast(cast: BattleAttackInstance, reason: StringName = &"completed", visual_spill: float = 0.0) -> void:
	if attack_instance == cast and cast.active:
		if reason == &"completed" and cast.timeline.effect_tail_frames > 0 and animation is SpineAnimationAdapter:
			animation.begin_effect_tail(cast.timeline.animation_action, cast.elapsed + visual_spill, (cast.timeline.duration_frames + cast.timeline.effect_tail_frames) / cast.timeline.source_fps)
		_finish_attack(reason)

func request_skill_operation(operation: StringName, id: StringName) -> bool:
	if session.is_simulation_blocked() or is_spawning() or not is_alive():
		return false
	if abilities.has_ability(id) and abilities.get_ability_instance(id).get_feature("BattleStatusActivationFeature") != null:
		return try_activate_skill(id, {"operation": operation})
	if _is_attack_state() and attack_instance != null:
		if attack_instance.buffer_operation(operation):
			return true
	return try_activate_skill(id, {"operation": operation})

func release_skill_operation(operation: StringName = &"") -> bool:
	if attack_instance == null or not attack_instance.active or attack_instance.timeline == null or not attack_instance.timeline.cancel_on_input_release:
		return false
	if not operation.is_empty() and attack_instance.initiating_operation != operation:
		return false
	cancel_skill(&"input_released" if not operation.is_empty() else &"control_lost")
	return true

func consume_skill_branch(cast: BattleAttackInstance) -> void:
	if attack_instance != cast or not cast.active or session.is_simulation_blocked():
		return
	var branch := cast.get_ready_branch()
	if branch == null or not abilities.has_ability(branch.target_ability_id):
		return
	var context := {"operation": branch.operation, "derived_from": cast.attack_id}
	if not abilities.can_activate_ability(branch.target_ability_id, context):
		return
	_cancel_abilities(&"derived")
	action_state.advance(0.0, action_profile, not is_zero_approx(move_axis), running)
	# 当前 GAS 容器循环结束后起手，避免派生技能在同一循环吃到整份旧 delta。
	_pending_derived_skill = {"id": branch.target_ability_id, "context": context}

func publish_battle_event(event_id: StringName, payload: Dictionary = {}) -> void:
	session.publish_event(event_id, self, self, payload)

func get_battle_random_int(minimum: int, maximum: int, stream: StringName = &"combat") -> int:
	return session.random.random_int(minimum, maximum, stream)

func get_battle_random_float(stream: StringName = &"combat") -> float:
	return session.random.random_float(stream)

func get_damage_rules() -> BattleDamageRules:
	return damage_rules

func get_damage_strategy() -> DamageLogicStrategy:
	return session.damage_strategy if session != null else null

func apply_status_definition(id: StringName, instigator: Node = null) -> GameplayStatusInstance:
	var data := session.catalog.instantiate_definition("statuses", id) as GameplayStatusData
	return statuses.apply_status(data, instigator if instigator != null else self) if data != null else null

func accepts_status_event(context: Dictionary) -> bool:
	if context.has("battle_id") and context.battle_id != session.battle_id:
		return false
	if context.has("battle_id") and (context.get("source_entity_id", &"") == entity_id or context.get("target_entity_id", &"") == entity_id):
		return true
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

#region Buff控制由标签与Core动作状态联合裁决
func can_use_ability(_id: StringName, _context: Dictionary = {}) -> bool:
	return not _cleaned and not is_spawning() and is_alive() and not TagManager.has_tag(self, &"state.stunned")

func can_receive_status(data: GameplayStatusData) -> bool:
	if _cleaned or is_spawning() or not is_alive():
		return false
	return not (data.tags.has(&"status.debuff") and (TagManager.has_tag(self, &"state.invulnerable") or TagManager.has_tag(self, &"state.debuff_immune") or (reactions._owner != null and not reactions.get_policy(self).status)))

func cleanup_death_statuses() -> void:
	if is_instance_valid(statuses) and not is_alive():
		statuses.clear_statuses(&"death")

func _sync_status_control() -> void:
	if action_state.registration_id.is_empty() or not is_alive():
		return
	if TagManager.has_tag(self, &"state.stunned"):
		if action_state.current != BattleActionState2D.State.STUN:
			cancel_skill(&"stunned")
			motion.clear_impulse()
			velocity.x = 0.0
			action_state.enter(BattleActionState2D.State.STUN)
			refresh_action_animation(true)
	elif action_state.current == BattleActionState2D.State.STUN:
		action_state.enter(BattleActionState2D.State.IDLE if motion.grounded else BattleActionState2D.State.JUMP)
		refresh_action_animation(true)
#endregion
