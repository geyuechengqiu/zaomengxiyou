extends GameplayVital
class_name ManaVital
#region 生命周期与引擎回调

## 法力值 Vital
## 处理消耗和恢复

func _init(p_comp: GameplayAttributeComponent = null) -> void:
	# 设置 ManaVital 的默认值（在调用 super 之前设置）
	vital_id = &"mana"
	display_name = "魔法值"
	max_value_attribute = &"mpMax"  # 依赖原版最大魔法属性作为上限
	# regen_rate_attribute = &"reMP"  # 可选：自动回复
#endregion
#region 公共接口
	
## 尝试消耗法力
## [param] amount: float 要消耗的法力值
## [return] bool 是否成功消耗
func try_spend_mana(amount: float) -> bool:
	if not _owner_comp.has_sufficient_vital(vital_id, amount):
		return false

	_owner_comp.modify_vital(vital_id, -amount)
	return true
#endregion
