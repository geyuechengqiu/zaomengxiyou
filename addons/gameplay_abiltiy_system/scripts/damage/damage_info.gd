extends RefCounted
class_name DamageInfo
#region 配置与运行状态

## 伤害信息数据包
## 包含伤害的所有相关信息

## 伤害来源
var instigator: Node = null                      ## 伤害的最终源头
var source_component: Node = null                ## 伤害的直接来源组件（采用鸭子类型，不依赖具体类型）

## 伤害属性
var base_damage : float = 0.0
var is_crit: bool = false                        ## 是否暴击
var final_damage: float = 0.0
## 一次命中共享同一个结果；计算阶段与生命应用阶段分离。
var calculated_damage: float = 0.0
var normal_damage: float = 0.0
var true_damage: float = 0.0
var shield_absorbed: float = 0.0
var actual_hp_loss: float = 0.0
var hp_before: float = 0.0
var hp_after: float = 0.0
var is_dodged: bool = false
var is_blocked: bool = false
var is_immune: bool = false
var applied: bool = false
## 计算器生成的单次命中不可重复应用；旧手工数据包保留可复用语义。
var single_use: bool = false
var hit_rate: float = 1.0
var crit_rate: float = 0.0
var crit_multiplier: float = 1.0
var trace: Array[Dictionary] = []
## 原版策略在 Vital 应用时按原顺序处理 Buff、护盾和角色回调。
## 明确的原版吸血阶段：伤害Buff之后、附伤与护盾之前。
var lifesteal_basis: float = 0.0
var lifesteal_requested: float = 0.0
var lifesteal_actual: float = 0.0
var application_resolver: Callable
#endregion
#region 生命周期与引擎回调

func _init(
		p_instigator: Node = null, 
		p_source_component: Node = null, 
		p_base_damage: float = 0.0, 
		) -> void:
	instigator = p_instigator
	source_component = p_source_component
	base_damage = p_base_damage
#endregion
#region 结果与审计
func scale_damage(multiplier: float) -> void:
	normal_damage *= multiplier
	true_damage *= multiplier
	final_damage *= multiplier

func record(stage: StringName, details: Dictionary = {}) -> void:
	var row := {"stage": stage, "normal": normal_damage, "true": true_damage}
	row.merge(details, true)
	trace.append(row)

func to_dictionary() -> Dictionary:
	return {"lifesteal_basis": lifesteal_basis, "lifesteal_requested": lifesteal_requested, "lifesteal_actual": lifesteal_actual, "calculated_damage": calculated_damage, "normal_damage": normal_damage,
		"true_damage": true_damage, "shield_absorbed": shield_absorbed,
		"actual_hp_loss": actual_hp_loss, "resolved_damage": final_damage,
		"hp_before": hp_before, "hp_after": hp_after, "is_dodged": is_dodged,
		"is_crit": is_crit, "is_blocked": is_blocked, "is_immune": is_immune,
		"hit_rate": hit_rate, "crit_rate": crit_rate, "crit_multiplier": crit_multiplier,
		"damage_trace": trace.duplicate(true), "damage_info": self}
#endregion
