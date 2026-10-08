extends GameplayEffect
class_name GE_OriginalBuffAttribute
#region 原版type8：施加时的all属性 × attributeV1 + attributeV3
@export var attribute_id: StringName = &"atk"
@export var ratio: float = 0.0
@export var fixed_bonus: float = 0.0

func _init() -> void:
	reapply_on_stack = true

func _apply(target: Node, _instigator: Node, context: Dictionary) -> void:
	var attributes := GameplayAbilitySystem.get_component_by_interface(target, &"GameplayVitalAttributeComponent") as BattleAttributeComponent
	if attributes == null or not attributes.has_attribute(attribute_id):
		return
	var state: Dictionary = context.get("effect_state", {})
	var key := StringName("basis." + String(attribute_id))
	if not state.has(key):
		state[key] = attributes.get_value(attribute_id)
	var amount := (float(state[key]) * ratio + fixed_bonus) * int(context.get("stacks", 1))
	attributes.replace_source(_source(context), [GameplayAttributeModifier.new(attribute_id, amount)])

func _remove(target: Node, _instigator: Node, context: Dictionary) -> void:
	var attributes := GameplayAbilitySystem.get_component_by_interface(target, &"GameplayVitalAttributeComponent") as BattleAttributeComponent
	if attributes != null:
		attributes.remove_modifiers_by_source(_source(context))

func _source(context: Dictionary) -> StringName:
	# 同一Buff可以同时修正多个属性，不覆盖兄弟效果的来源。
	return StringName(String(context.source_id) + ".original_attribute." + String(attribute_id))
#endregion
