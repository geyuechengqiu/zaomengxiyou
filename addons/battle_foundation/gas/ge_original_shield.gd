extends GameplayEffect
class_name GE_OriginalShield
#region 原版type262：allhpMax × V1 + allatk × V2 + V3
@export var health_ratio: float = 0.0
@export var attack_ratio: float = 0.0
@export var fixed_amount: float = 0.0

func _init() -> void:
	reapply_on_stack = true

func _apply(target: Node, _instigator: Node, context: Dictionary) -> void:
	var attributes := GameplayAbilitySystem.get_component_by_interface(target, &"GameplayVitalAttributeComponent") as BattleAttributeComponent
	if attributes == null or not target.has_method("get_damage_rules"):
		return
	var amount := (attributes.get_value(&"hpMax") * health_ratio + attributes.get_value(&"atk") * attack_ratio + fixed_amount) * int(context.get("stacks", 1))
	target.get_damage_rules().grant_shield(StringName(String(context.source_id) + ".original_shield"), maxf(0.0, amount))

func _remove(target: Node, _instigator: Node, context: Dictionary) -> void:
	if target.has_method("get_damage_rules"):
		target.get_damage_rules().remove_source(StringName(String(context.source_id) + ".original_shield"))
#endregion
