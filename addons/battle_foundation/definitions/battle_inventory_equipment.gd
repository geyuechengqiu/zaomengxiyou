extends Equip
class_name BattleInventoryEquipment
#region 背包装备与战斗定义适配
## Simple Inventory 负责物品和槽位，GAS 负责属性；装备定义保持只读。
@export var battle_definition: BattleEquipmentDefinition
## 离线依据Resource.normal映射至现有动画适配层皮肤；为空保留基础外观。
@export var appearance_skin: StringName

func _init() -> void:
	category = Item.ITEM_TYPE.EQUIPMENT
#endregion
