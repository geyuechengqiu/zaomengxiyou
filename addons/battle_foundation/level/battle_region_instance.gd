extends RefCounted
class_name BattleRegionInstance
#region 本次关卡区域状态
var definition: BattleRegionDefinition
var entered: bool = false
var entered_at: float = INF
var completed: bool = false
var exit_open: bool = false
var exited: bool = false
#endregion
