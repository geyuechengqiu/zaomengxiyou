extends GameplayEffect
class_name GE_BattleDamageRules
#region GAS状态规则与护盾效果
@export var rules: Dictionary = {}
@export var shield_amount: float = 0.0

func _apply(target: Node, _instigator: Node, context: Dictionary) -> void:
	if not target.has_method("get_damage_rules"):
		return
	var runtime: BattleDamageRules = target.get_damage_rules()
	var source := StringName(context.get("source_id", "effect." + resource_path))
	var values := rules.duplicate(true)
	var stacks := int(context.get("stacks", 1))
	for key in values:
		if values[key] is float or values[key] is int:
			values[key] *= stacks
	runtime.set_source(source, values)
	runtime.grant_shield(source, shield_amount * stacks)

func _remove(target: Node, _instigator: Node, context: Dictionary) -> void:
	if target.has_method("get_damage_rules"):
		target.get_damage_rules().remove_source(StringName(context.get("source_id", "effect." + resource_path)))
#endregion
