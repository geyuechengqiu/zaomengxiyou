extends RefCounted
class_name BattleWaveInstance
#region 本次关卡波次状态
var definition: BattleWaveDefinition
var started: bool = false
var started_at: float = INF
var completed: bool = false
var completed_at: float = INF
#endregion
