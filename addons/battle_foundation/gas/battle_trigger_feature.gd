extends StatusFeature
class_name BattleTriggerFeature
#region 被动的事件、角色与触发条件
enum OwnerRole { SOURCE, TARGET, EITHER }
enum EffectTarget { OWNER, EVENT_SOURCE, EVENT_TARGET }
@export var trigger_on_events: Array[StringName] = []
@export var owner_role: OwnerRole = OwnerRole.SOURCE
@export var effect_target: EffectTarget = EffectTarget.OWNER
@export var effects: Array[GameplayEffect] = []
@export_range(0.0, 1.0) var chance: float = 1.0
@export var cooldown: float = 0.0
@export_range(0.0, 1.0) var health_threshold: float = 0.0
@export var threshold_falling: bool = true
@export var allow_secondary_damage: bool = false

func has_event_listening() -> bool:
	return not trigger_on_events.is_empty()

func can_trigger_on_event(id: StringName) -> bool:
	return trigger_on_events.has(id)

func _update_feature(instance: GameplayStatusInstance, delta: float) -> void:
	var state := instance.get_feature_storage(self)
	state["cooldown"] = maxf(0.0, float(state.get("cooldown", 0.0)) - delta)

func _handle_event(instance: GameplayStatusInstance, id: StringName, context: Dictionary) -> void:
	if not trigger_on_events.has(id) or instance.removed:
		return
	var owner := instance.owner_component.get_parent()
	var source: Node = owner.session.get_entity(StringName(context.get("source_entity_id", &"")))
	var target: Node = owner.session.get_entity(StringName(context.get("target_entity_id", &"")))
	if (owner_role == OwnerRole.SOURCE and source != owner) or (owner_role == OwnerRole.TARGET and target != owner) or (owner_role == OwnerRole.EITHER and source != owner and target != owner):
		return
	if not allow_secondary_damage and StringName(context.get("damage_kind", &"attack")) != &"attack":
		return
	var state := instance.get_feature_storage(self)
	var chain: Array = context.get("trigger_chain", []).duplicate()
	var key := "%d/%d" % [instance.get_instance_id(), get_instance_id()]
	if bool(state.get("busy", false)) or float(state.get("cooldown", 0.0)) > 0.000000001 or chain.has(key) or chain.size() >= GameplayTriggerGuard.MAX_DEPTH:
		return
	if health_threshold > 0.0:
		var previous := float(context.get("previous_health_ratio", -1.0))
		var current := float(context.get("health_ratio", -1.0))
		if previous < 0.0 or current < 0.0:
			return
		if threshold_falling and not (previous > health_threshold and current <= health_threshold):
			return
		if not threshold_falling and not (previous < health_threshold and current >= health_threshold):
			return
	if chance <= 0.0 or (chance < 1.0 and owner.get_battle_random_float(&"combat") >= chance):
		return
	var recipient: Node = owner if effect_target == EffectTarget.OWNER else (source if effect_target == EffectTarget.EVENT_SOURCE else target)
	if not is_instance_valid(recipient):
		return
	chain.append(key)
	var execution := context.duplicate()
	execution["trigger_chain"] = chain
	execution["trigger_owner"] = owner
	execution["trigger_event"] = id
	state["busy"] = true
	state["cooldown"] = maxf(0.0, cooldown)
	state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
	instance.apply_effects_to(effects, recipient, owner, execution)
	state["busy"] = false
#endregion
