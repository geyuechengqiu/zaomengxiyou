extends RefCounted
class_name InventoryItemState
#region 单个物品的可保存运行状态；定义始终只读
var unique_id: String = ""
var enhancement_level: int = 0
var rolled_attributes: Dictionary = {}
var random_affixes: Dictionary = {}
var additional_attributes: Dictionary = {}
var owner_inventory_id: int = 0

func to_dictionary() -> Dictionary:
	return {"unique_id": unique_id, "enhancement_level": enhancement_level, "rolled_attributes": rolled_attributes.duplicate(true), "random_affixes": random_affixes.duplicate(true), "additional_attributes": additional_attributes.duplicate(true)}

static func from_dictionary(data: Dictionary) -> InventoryItemState:
	var state := InventoryItemState.new()
	state.unique_id = String(data.get("unique_id", ""))
	state.enhancement_level = maxi(0, int(data.get("enhancement_level", 0)))
	for field in ["rolled_attributes", "random_affixes", "additional_attributes"]:
		state.set(field, data.get(field, {}).duplicate(true))
	return state
#endregion
