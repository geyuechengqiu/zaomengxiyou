extends RefCounted
class_name BattleSpawnPlanInstance
#region 本次关卡出生计划状态
var definition: BattleSpawnPlanDefinition
var started: bool = false
var created: int = 0
var next_due: float = INF
var generation_complete_at: float = INF
var all_dead_at: float = INF
var targets: Dictionary = {}
var dead_targets: Dictionary = {}
var all_dead_notified: bool = false

func generation_complete() -> bool:
	return started and created == definition.monster_ids.size()

func all_dead() -> bool:
	return generation_complete() and dead_targets.size() == definition.monster_ids.size()
#endregion
