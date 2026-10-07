extends Resource
class_name BattleEntityDefinition
#region 共享定义
## 只保存初始配置，当前生命/速度/阵营/技能实例由 BattleEntity 持有。
@export var definition_id: StringName = &""
@export var display_name: String = ""
@export var faction_id: StringName = &"neutral"
@export var scene: PackedScene
@export var attribute_set: GameplayAttributeSet
@export var progression: BattleAttributeProgression
@export_range(1, 10000) var initial_level: int = 1
@export var vitals: Array[GameplayVital] = []
@export var ability_ids: Array[StringName] = []
@export var initial_status_ids: Array[StringName] = []
#endregion
#region 只读场景模板
func _validate_property(property: Dictionary) -> void:
	if property.name == "scene":
		property.usage |= PROPERTY_USAGE_NEVER_DUPLICATE
#endregion
