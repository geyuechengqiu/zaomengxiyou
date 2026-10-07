extends Resource
class_name BattleEquipmentDefinition
#region 共享定义
@export var definition_id: StringName = &""
@export var display_name: String = ""
@export var slot_id: StringName = &"weapon"
@export var max_durability: float = 100.0
@export var attribute_modifiers: Array[GameplayAttributeModifier] = []
#endregion
