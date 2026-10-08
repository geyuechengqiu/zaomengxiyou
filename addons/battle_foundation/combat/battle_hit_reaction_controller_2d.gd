extends Node
class_name BattleHitReactionController2D
#region 配置与运行状态
## 收到一次已裁决的命中后只处理动作/物理，不计算 HP，也不靠动画回调解锁。

var _owner: WeakRef
#endregion
#region 公共接口

func bind(actor: BattleEntity2D) -> void:
	_owner = weakref(actor)

func is_armored(actor: BattleEntity2D) -> bool:
	return actor.super_armor or bool(actor.action_state.active_rules.get("super_armor", false)) or TagManager.has_tag(actor, &"state.super_armor") or (actor.protection.active and actor.protection.profile.use_as_armor)

#endregion
#region 无敌与保护分别明确阻止的效果
func get_policy(actor: BattleEntity2D) -> Dictionary:
	var definition := actor.reaction_profile
	var invulnerable := TagManager.has_tag(actor, &"state.invulnerable") or actor.damage_rules.has_flag(&"immune") or (definition.getup_invulnerable and actor.action_state.current == BattleActionState2D.State.GETUP)
	var result := {"damage": true, "reaction": true, "displacement": true, "status": true, "protection": true, "hit_stop": true}
	if invulnerable:
		result.damage = false
		result.reaction = not definition.invulnerable_blocks_reaction
		result.displacement = not definition.invulnerable_blocks_displacement
		result.status = not definition.invulnerable_blocks_status
		result.protection = not definition.invulnerable_blocks_protection
		result.hit_stop = not definition.invulnerable_blocks_hit_stop
	if actor.protection.active:
		var protect := actor.protection.profile
		result.damage = result.damage and not protect.blocks_damage
		result.reaction = result.reaction and not protect.blocks_reaction
		result.displacement = result.displacement and not protect.blocks_displacement
		result.status = result.status and not protect.blocks_status
	return result
#endregion
#region 独立动作、方向与位移裁决
func resolve(info: DamageInfo, context: Dictionary, kind: StringName, priority: int, policy: Dictionary) -> Dictionary:
	var actor := _owner.get_ref() as BattleEntity2D if _owner != null else null
	var result := {"reaction_applied": false, "displacement_applied": false, "reason": &"none"}
	if actor == null or actor.animation == null or not actor.is_alive() or info.is_dodged:
		return result
	var definition := actor.reaction_profile
	if info.actual_hp_loss <= 0.0 and not definition.react_on_zero_damage:
		return result
	var armored := is_armored(actor)
	var armor_rejected := armored and definition.armor_blocks_kinds.has(kind)
	# Core 保留技能自身的可打断种类及强度门槛；目标霸体种类另由本资源裁决。
	var can_interrupt := not armor_rejected and actor.action_state.can_interrupt(kind, priority, false, actor.action_profile)
	var reaction_type := StringName(context.get("reaction_type", &"auto"))
	var stun := float(context.get("hit_stun", -1.0))
	if stun < 0.0:
		stun = actor.action_profile.hurt_lock_frames / actor.action_profile.source_fps
	stun *= 1.0 - definition.stun_resistance
	var launch := maxf(0.0, float(context.get("launch_speed", 0.0))) * (1.0 - definition.launch_resistance)
	var direction := _get_direction(actor, info.instigator, context)
	var duration := maxf(0.0, float(context.get("knockback_duration", 0.0)))
	var horizontal := float(context.get("knockback_speed", 0.0))
	if StringName(context.get("knockback_mode", &"speed")) == &"displacement":
		horizontal = float(context.get("knockback_distance", 0.0)) / duration if duration > 0.0 else 0.0
	horizontal *= direction * (1.0 - definition.knockback_resistance)
	var allow_motion: bool = policy.displacement and can_interrupt and reaction_type != &"none"
	if armor_rejected and not definition.armor_blocks_displacement:
		allow_motion = bool(policy.displacement) and reaction_type != &"none"
	if actor.protection.active and policy.displacement:
		# 保护可以只防硬直却允许位移，不把 Core 的高打断门槛当位移免疫。
		allow_motion = reaction_type != &"none"
	if allow_motion:
		actor.motion.apply_impulse(horizontal, duration, launch, float(context.get("reaction_gravity", -1.0)), bool(context.get("reset_vertical_velocity", false)))
		result.displacement_applied = (not is_zero_approx(horizontal) and duration > 0.0) or launch > 0.0
	if policy.reaction and can_interrupt and reaction_type != &"none" and (stun > 0.0 or launch > 0.0 or reaction_type == &"knockdown"):
		actor.cancel_skill(&"interrupted")
		var rules := {"hurt_lock_seconds": stun, "hit_landing_seconds": definition.hit_landing_seconds, "knockdown_seconds": definition.knockdown_seconds, "getup_seconds": definition.getup_seconds, "knockdown_after_land": bool(context.get("knockdown", false)) or reaction_type == &"knockdown"}
		var state: int = BattleActionState2D.State.LAUNCHED if launch > 0.0 and allow_motion else BattleActionState2D.State.HURT
		actor.action_state.enter(state, rules)
		actor.refresh_action_animation(true)
		result.reaction_applied = true
		result.reason = &"accepted"
	elif armor_rejected or not can_interrupt:
		result.reason = &"armor" if armor_rejected else &"priority"
		actor.publish_battle_event(&"battle.interrupt_rejected", {"interrupt_kind": kind, "reason": result.reason})
	else:
		result.reason = &"policy" if not policy.reaction else &"none"
	if result.reaction_applied or result.displacement_applied:
		actor.publish_battle_event(&"battle.hit.reaction", {"attack_id": context.get("attack_id", &""), "hit_index": context.get("hit_index", 1), "reaction_type": reaction_type, "knockback_speed": horizontal if allow_motion else 0.0, "launch_speed": launch if allow_motion else 0.0, "hit_stun": stun, "direction": direction, "reaction_applied": result.reaction_applied, "displacement_applied": result.displacement_applied})
	return result

func _get_direction(actor: BattleEntity2D, attacker: Node, context: Dictionary) -> int:
	match StringName(context.get("knockback_direction", &"attack_facing")):
		&"away_from_attacker":
			if attacker is Node2D and not is_zero_approx(actor.global_position.x - attacker.global_position.x):
				return 1 if actor.global_position.x > attacker.global_position.x else -1
		&"target_facing":
			return actor.animation.get_facing()
		&"explicit":
			return -1 if int(context.get("knockback_sign", 1)) < 0 else 1
	return -1 if int(context.get("attack_facing", 1)) < 0 else 1
#endregion
#region 保护动作不等于免伤：清理技能/预约，使用真实 Core 叶子锁定
func start_protection() -> bool:
	var actor := _owner.get_ref() as BattleEntity2D
	if actor == null or not actor.is_alive() or TagManager.has_tag(actor, &"state.stunned") or not actor.protection.profile.protection_action_enabled:
		return false
	var definition := actor.protection.profile
	if not definition.protect_ability_id.is_empty() and (not actor.abilities.has_ability(definition.protect_ability_id) or not actor.abilities.can_activate_ability(definition.protect_ability_id, {})):
		return false
	actor.cancel_skill(&"protection")
	actor.motion.clear_impulse()
	if not definition.protect_ability_id.is_empty() and not actor.abilities.try_activate_ability(definition.protect_ability_id, {"protection": true}):
		return false
	actor.action_state.enter(BattleActionState2D.State.PROTECT, {"protect_seconds": definition.protect_seconds, "interrupt_priority": 1000 if definition.blocks_reaction else 0})
	actor.refresh_action_animation(true)
	return actor.action_state.current == BattleActionState2D.State.PROTECT
#endregion
