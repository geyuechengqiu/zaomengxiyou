extends Resource
class_name BattleLevelDefinition
#region 共享定义
@export var definition_id: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
@export var spawns: Array[BattleSpawnDefinition] = []
#endregion
