extends AbilityCostBase
class_name VitalCost
#region 配置与运行状态

## Vital 消耗器
## 消耗指定的 Vital（如魔法值、怒气、能量、生命值等）

@export_group("Vital Cost")
## 要消耗的 Vital ID（如 "mana", "rage", "energy", "health"）
@export var vital_id: StringName = &"mana"
## 消耗数量
@export var amount: float = 10.0
## 是否允许透支（如果为 false，必须完全满足才能消耗）
@export var allow_overdraft: bool = false
## vital组件的称
@export var vital_comp_name : StringName = "GameplayVitalAttributeComponent"

#endregion
#region 内部实现

func _can_pay(ability_comp: Node, instigator: Node) -> bool:
	if not is_instance_valid(instigator):
		push_warning("VitalCost: Cannot find instigator")
		return false

	var vital_comp := _resolve_vital(instigator)
	if vital_comp == null or not is_finite(amount) or amount < 0.0:
		return false

	# 检查是否有足够的 Vital
	if allow_overdraft:
		# 允许透支，只要有 Vital 就可以（即使不足）
		return vital_comp.has_vital(vital_id) and vital_comp.get_vital_value(vital_id) > 0.0
	else:
		# 不允许透支，必须完全满足
		return vital_comp.has_sufficient_vital(vital_id, amount)

func _try_pay(ability_comp: Node, instigator: Node) -> bool:
	if not is_instance_valid(instigator):
		push_warning("VitalCost: Cannot find instigator")
		return false

	var vital_comp := _resolve_vital(instigator)
	if vital_comp == null or not _can_pay(ability_comp, instigator):
		return false
	
	# 使用通用方法
	if allow_overdraft:
		# 允许透支，直接消耗（可能变成负数）
		vital_comp.modify_vital(vital_id, -amount)
		return true
	else:
		# 不允许透支，使用 modify_vital（会自动检查）
		return vital_comp.modify_vital(vital_id, -amount)

func _get_cost_description() -> String:
	return "消耗 %s: %.0f" % [vital_id, amount]

func _resolve_vital(instigator: Node) -> GameplayVitalAttributeComponent:
	# Resource 可以被多个技能实例共享，不能在定义中缓存第一个宿主的组件。
	return GameplayAbilitySystem.get_component_by_interface(instigator, vital_comp_name) as GameplayVitalAttributeComponent
#endregion
