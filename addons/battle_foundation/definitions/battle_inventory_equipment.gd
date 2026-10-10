extends Equip
class_name BattleInventoryEquipment
#region 背包装备与战斗定义适配
## Simple Inventory 负责物品和槽位，GAS 负责属性；装备定义保持只读。
@export var battle_definition: BattleEquipmentDefinition
## 离线依据Resource.normal映射至现有动画适配层皮肤；为空保留基础外观。
@export var appearance_skin: StringName
## 同一数值定义可对不同角色指定各自皮肤，不让插件硬编码角色ID。
@export var appearance_skins: Dictionary[StringName, StringName] = {}

func get_appearance_skin(character_id: StringName) -> StringName:
	return appearance_skins.get(character_id, appearance_skin)

func _init() -> void:
	category = Item.ITEM_TYPE.EQUIPMENT
#endregion
