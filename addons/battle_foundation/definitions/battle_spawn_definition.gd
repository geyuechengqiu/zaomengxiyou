extends Resource
class_name BattleSpawnDefinition
#region 共享定义
@export_enum("characters", "monsters") var category: String = "monsters"
@export var entity_definition_id: StringName = &""
@export var faction_override: StringName = &""
@export var position: Vector3 = Vector3.ZERO
#endregion
