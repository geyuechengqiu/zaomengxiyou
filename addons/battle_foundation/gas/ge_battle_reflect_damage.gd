extends GameplayEffect
class_name GE_BattleReflectDamage
#region 原版type15：最终普通与真实分量之和 × fangShang，直接扣血而不再次计算攻击
@export var ratio: float = 0.35
@export var attack_cap_ratio: float = 0.0
@export var fixed_damage: float = 0.0

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	if not target.has_method("receive_damage_info") or not is_instance_valid(instigator):
		return
	var amount := maxf(0.0, float(context.get("resolved_damage", 0.0))) * ratio * int(context.get("stacks", 1)) + fixed_damage
	if attack_cap_ratio > 0.0:
		amount = minf(amount, instigator.attributes.get_value(&"atk") * attack_cap_ratio)
	if amount > 0.0:
		target.session.apply_secondary_damage(target, instigator, amount, &"reflection", context)
#endregion
