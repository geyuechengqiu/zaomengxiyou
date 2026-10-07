extends RefCounted
class_name BattleEquipmentState
#region 装备运行状态
var instance_id: StringName = &""
var definition: BattleEquipmentDefinition
var durability: float = 0.0
#endregion
#region 公共接口
func initialize(id: StringName, data: BattleEquipmentDefinition) -> void:
	instance_id = id
	definition = data
	durability = data.max_durability
#endregion
