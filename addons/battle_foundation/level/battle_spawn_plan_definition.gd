extends Resource
class_name BattleSpawnPlanDefinition
#region 出生计划只读定义
@export var plan_id: StringName
@export var spawn_point_id: StringName
## 有序生成列表。不会在共享资源上shift/pop，游标属于运行实例。
@export var monster_ids: Array[StringName] = []
@export_range(0, 600) var delay_seconds: float = 0.0
@export_range(0, 600) var interval_seconds: float = 0.0
## 原版首只等待delayTime+interval，后续仅等待interval。
@export var after_created_plan_ids: Array[StringName] = []
@export var after_dead_plan_ids: Array[StringName] = []
@export var required_conditions: Array[StringName] = []
@export var participates_in_clear: bool = true
@export var is_boss: bool = false
@export_enum("左:-1", "右:1") var facing: int = 1
#endregion
