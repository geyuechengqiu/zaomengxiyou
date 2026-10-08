extends Resource
class_name BattleAIPolicy2D
#region 决策资源扩展点
## 只返回意图，不修改角色状态、位置、生命或技能黑板。每实例状态放在controller。
func decide(_controller: BattleAIController2D) -> Dictionary:
	return {"state": &"IDLE", "axis": 0.0}
#endregion
