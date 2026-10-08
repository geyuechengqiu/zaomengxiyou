extends GameplayEffect
class_name GE_ApplyDamage
#region 配置与运行状态

## 应用伤害效果
## 默认会阻挡带有 state.invulnerable 标签的目标（免疫伤害）

@export var damage_multiplier: float = 1.0  ## 伤害倍数
@export var invulnerable_block_tag: StringName = &"state.invulnerable"  ## 免疫伤害标签
@export var damage_strategy : DamageLogicStrategy = null
@export var vital_comp_name : StringName = &"GameplayVitalAttributeComponent"
@export var vital_id : StringName = &"health"
#endregion
#region 生命周期与引擎回调

func _init() -> void:
	# 为伤害效果提供默认的免疫标签，避免在每个资源里手工配置
	if target_blocked_tags.is_empty() and not invulnerable_block_tag.is_empty():
		target_blocked_tags = [invulnerable_block_tag]
#endregion
#region 内部实现

## 原版免疫在结算末尾处理，保留结构化结果；其他过滤器仍照常工作。
func _check_filters(target: Node, instigator: Node, context: Dictionary) -> bool:
	var selected := DamageCalculator.resolve_strategy(instigator, context, damage_strategy)
	if selected == null or not selected.resolves_invulnerability():
		return super._check_filters(target, instigator, context)
	for filter: GameplayFilterData in filters:
		if not filter.check(target, instigator, context):
			return false
	for tag in target_blocked_tags:
		if tag != invulnerable_block_tag and TagManager.has_tag(target, tag):
			return false
	return target_required_tags.is_empty() or TagManager.has_all_tags(target, target_required_tags)

func _apply(target: Node, instigator: Node, context: Dictionary) -> void:
	var calculation_context := context.duplicate()
	calculation_context["damage_multiplier_modifier"] = float(context.get("damage_multiplier_modifier", 1.0)) * damage_multiplier
	
	# 1. 获取 HealthVital
	var vital_comp = GameplayAbilitySystem.get_component_by_interface(target, vital_comp_name)
	if not is_instance_valid(vital_comp):
		return
	var health_vital: HealthVital = vital_comp.get_vital(vital_id)
	if health_vital == null:
		return
	
	# 直接从 context Dictionary 读取
	var stacks = context.get("stacks", 1)
	
	# 2. 计算最终伤害
	var damage_info := DamageCalculator.calculate_damage(target, instigator, calculation_context, damage_strategy)
	
	# 3. 创建 DamageInfo
	damage_info.scale_damage(stacks)
	damage_info.calculated_damage *= stacks
	
	# 4. 应用伤害（由 HealthVital 负责）
	if vital_id == &"health" and target.has_method("receive_damage_info"):
		# 战斗宿主统一裁决无敌的各类效果、保护与反应；不再绕过其命中入口。
		target.receive_damage_info(damage_info, StringName(context.get("interrupt_kind", &"normal")), int(context.get("interrupt_priority", 60)), calculation_context)
	else:
		health_vital.apply_damage(damage_info, target)
	
	# 5. 保存到上下文
	context["final_damage"] = damage_info.actual_hp_loss
	context["damage_info"] = damage_info
	context.merge(damage_info.to_dictionary(), true)
#endregion
