extends DamageLogicStrategy
class_name SimpleDamageLogic
#region 配置与运行状态

## ARPG 伤害计算策略
## 当前公式：max(1, atk - phyDef) × 上下文倍率 + 固定附伤；原版暴击评分尚未参与结算。

@export var attack_attribute: StringName = &"atk"  ## 攻击力属性
@export var defense_attribute: StringName = &"phyDef"   ## 防御力属性
@export var crit_rate_attribute: StringName = &""  ## 预留概率属性 ID；原版 critical 是评分，默认不绑定
@export var crit_multiplier: float = 2.0  ## 暴击倍数
#endregion
#region 公共接口

func calculate(target: Node, instigator: Node, context: Dictionary) -> float:
	var attacker_comp = GameplayAbilitySystem.get_component_by_interface(instigator, "GameplayVitalAttributeComponent")
	if not is_instance_valid(attacker_comp):
		return 0.0
	
	var base_attack = attacker_comp.get_value(attack_attribute)
	var defense_comp = GameplayAbilitySystem.get_component_by_interface(target, "GameplayVitalAttributeComponent")
	var defense = defense_comp.get_value(defense_attribute)
	
	# 计算基础伤害
	var base_damage = max(1, base_attack - defense)
	base_damage *= context.get("damage_multiplier", 1.0)
	base_damage *= context.get("damage_multiplier_modifier", 1.0)
	
	return base_damage + maxf(0.0, float(context.get("fixed_damage", 0.0)))
#endregion
