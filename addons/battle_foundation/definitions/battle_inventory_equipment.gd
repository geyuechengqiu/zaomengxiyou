extends Equip
class_name BattleInventoryEquipment
#region 背包装备与战斗定义适配
## Simple Inventory 负责物品和槽位，GAS 负责属性；装备定义保持只读。
@export var battle_definition: BattleEquipmentDefinition

func _init() -> void:
	category = Item.ITEM_TYPE.EQUIPMENT
#endregion
