extends AbilityCostBase
class_name BattleSkillManaCost
#region 按原版技能等级消耗魔法，不修改共用资源
@export var skill_id: StringName
@export var amounts: Array[float] = []

func get_amount(component: Node, owner: Node, context: Dictionary = {}) -> float:
	var ability: GameplayAbilityInstance = component.get_ability_instance(skill_id)
	if context.is_empty() and ability != null and ability.is_active:
		context = ability.get_blackboard_var("context", {})
	return BattleSkillLevelValues.sample(amounts, BattleSkillLevelValues.get_level(owner, skill_id, context))

func can_pay_context(component: Node, owner: Node, context: Dictionary) -> bool:
	var vital := GameplayAbilitySystem.get_component_by_interface(owner, "GameplayVitalAttributeComponent") as GameplayVitalAttributeComponent
	return vital != null and vital.has_sufficient_vital(&"mana", get_amount(component, owner, context))

func try_pay_context(component: Node, owner: Node, context: Dictionary) -> bool:
	if not can_pay_context(component, owner, context): return false
	var vital := GameplayAbilitySystem.get_component_by_interface(owner, "GameplayVitalAttributeComponent") as GameplayVitalAttributeComponent
	return vital.modify_vital(&"mana", -get_amount(component, owner, context))

func _can_pay(component: Node, owner: Node) -> bool:
	var vital := GameplayAbilitySystem.get_component_by_interface(owner, "GameplayVitalAttributeComponent") as GameplayVitalAttributeComponent
	var amount := get_amount(component, owner)
	return vital != null and is_finite(amount) and amount >= 0.0 and vital.has_sufficient_vital(&"mana", amount)

func _try_pay(component: Node, owner: Node) -> bool:
	var vital := GameplayAbilitySystem.get_component_by_interface(owner, "GameplayVitalAttributeComponent") as GameplayVitalAttributeComponent
	return vital != null and vital.modify_vital(&"mana", -get_amount(component, owner))
#endregion
