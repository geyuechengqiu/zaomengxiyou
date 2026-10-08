extends Node
class_name BattleDamageRulesComponent
## 场景预置的伤害规则容器；护盾、回调和技能等级是每实体独立的运行数据。
#region 实例数据与场景生命周期
var rules := BattleDamageRules.new()

func _exit_tree() -> void:
	rules.clear()
#endregion
