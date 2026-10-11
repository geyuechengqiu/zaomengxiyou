extends GameplayEffect
class_name GE_OriginalPeriodicVital
#region 原版type5：目标allhpMax × V1 + 目标allatk × V2 + V3，再int截断
@export var health_ratio: float = 0.0
@export var attack_ratio: float = 0.0
@export var fixed_delta: float = 0.0
@export var show_value_on_head: bool = false

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	if not target.has_method("is_alive") or not target.is_alive():
		return
	var attributes := GameplayAbilitySystem.get_component_by_interface(target, &"GameplayVitalAttributeComponent") as BattleAttributeComponent
	var delta := int(attributes.get_value(&"hpMax") * health_ratio + attributes.get_value(&"atk") * attack_ratio + fixed_delta) * int(context.get("stacks", 1))
	if delta >= 0:
		var health := attributes.get_vital(&"health") as HealthVital
		var before := health.current_value
		health.heal(delta)
		var amount := int(health.current_value - before)
		if show_value_on_head and amount > 0 and target.feedback != null:
			target.feedback.show_supply_recovery(&"health", amount)
	else:
		target.session.apply_secondary_damage(target, instigator, -delta, &"periodic", context)
#endregion
