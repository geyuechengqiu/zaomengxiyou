extends BattleAIPolicy2D
class_name BattleSupportAIPolicy2D
#region 支援技能按自身冷却释放，不依赖敌方进入攻击距离
func decide(controller: BattleAIController2D) -> Dictionary:
	return {"state": &"SUPPORT" if controller.skill_ready() else &"COOLDOWN", "axis": 0.0, "skill": controller.profile.attack_skill_id if controller.skill_ready() else &""}
#endregion
