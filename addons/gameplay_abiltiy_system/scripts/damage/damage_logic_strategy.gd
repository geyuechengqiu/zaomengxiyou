@abstract
extends Resource
class_name DamageLogicStrategy
#region 公共接口

## 伤害计算策略基类
## 业务层继承此类并重写 calculate 方法来自定义伤害公式

## 核心计算接口
## [param] damage_info: DamageInfo 伤害信息（包含基础伤害、攻击者等）
## [param] target_attributes: GameplayAttributeComponent 防御者的属性组件
## [return] float 最终伤害值
@abstract func calculate(target: Node, instigator: Node, context: Dictionary) -> float

## 兼容只有浮点接口的插件策略。
func calculate_result(target: Node, instigator: Node, context: Dictionary) -> DamageInfo:
	var value := maxf(0.0, calculate(target, instigator, context))
	var result := DamageInfo.new(instigator, context.get("source_node"), value)
	result.single_use = true
	result.final_damage = value
	result.normal_damage = value
	result.calculated_damage = value
	return result

func resolves_invulnerability() -> bool:
	return false
#endregion
