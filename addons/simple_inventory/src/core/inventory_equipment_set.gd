extends Resource
class_name InventoryEquipmentSet
#region 可复用套装定义；累计触发所有已达到的件数门槛
@export var set_id: StringName
@export var display_name: String
@export var item_ids: Array[StringName] = []
## 例：[{"pieces":2,"attributes":{"atk":10}}, {"pieces":3,"attributes":{"hpMax":50}}]
@export var bonuses: Array[Dictionary] = []
#endregion
