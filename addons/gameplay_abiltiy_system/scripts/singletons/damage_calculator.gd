extends Node
#region 配置与运行状态

## 伤害计算中心（单例）
## 使用策略模式，支持自定义伤害公式

var _strategy: DamageLogicStrategy = SimpleDamageLogic.new()
#endregion
#region 公共接口

## 设置伤害计算策略
## [param] strategy: DamageLogicStrategy 自定义策略
func set_strategy(strategy: DamageLogicStrategy) -> void:
	_strategy = strategy

## 计算最终伤害
## [param] damage_info: DamageInfo 伤害信息
## [param] target_comp: GameplayAttributeComponent 目标的属性组件
## [return] float 最终伤害值
func calculate_final_damage(target: Node, instigator: Node, context: Dictionary, strategy: DamageLogicStrategy = null) -> float:
	return calculate_damage(target, instigator, context, strategy).calculated_damage

## 一次攻击只调用一次，随后把同一 DamageInfo 交给 Vital。
func calculate_damage(target: Node, instigator: Node, context: Dictionary, strategy: DamageLogicStrategy = null) -> DamageInfo:
	var selected := resolve_strategy(instigator, context, strategy)
	return selected.calculate_result(target, instigator, context) if selected != null else DamageInfo.new(instigator)

func resolve_strategy(instigator: Node, context: Dictionary, strategy: DamageLogicStrategy = null) -> DamageLogicStrategy:
	var selected: DamageLogicStrategy = context.get("damage_strategy", strategy)
	if selected == null and is_instance_valid(instigator) and instigator.has_method("get_damage_strategy"):
		selected = instigator.get_damage_strategy()
	if selected == null:
		selected = _strategy
	return selected
#endregion
