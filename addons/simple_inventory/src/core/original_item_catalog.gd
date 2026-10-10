extends RefCounted
class_name OriginalItemCatalog
#region 业务JSON -> 只读物品定义；运行时状态由Item.create_instance管理
var definitions: Dictionary[StringName, Item] = {}

func configure(rows: Dictionary) -> void:
	definitions.clear()
	for key in rows:
		var row: Dictionary = rows[key]
		var data: Dictionary = row.data
		var item: Item = BattleInventoryEquipment.new() if String(data.get("type", "")) == "equipment" else Item.new()
		item.item_id = StringName(key)
		item.name = String(data.get("name", key))
		item.description = String(data.get("describe", ""))
		item.original_data = data.duplicate(true)
		item.icon = load(String(row.icon)) as Texture2D
		item.pickup_icon = load(String(row.get("pickup_icon", row.icon))) as Texture2D
		if item is BattleInventoryEquipment:
			var equipment := BattleEquipmentDefinition.new()
			equipment.definition_id = item.item_id
			equipment.display_name = item.name
			equipment.slot_id = StringName(data.get("part", ""))
			for id in OriginalItemPresenter.ATTRIBUTE_NAMES:
				var raw := String(str(data.get(String(id), "0"))).split(";")[0]
				if raw.is_valid_float() and float(raw) != 0: equipment.attribute_modifiers.append(GameplayAttributeModifier.new(id, float(raw)))
			item.battle_definition = equipment
			for character in row.get("appearance_skins", {}): item.appearance_skins[StringName(character)] = StringName(row.appearance_skins[character])
		else:
			item.category = Item.ITEM_TYPE.CONSUMABLE if int(data.get("isConsume", 0)) != 0 else Item.ITEM_TYPE.MATERIAL
			item.max_stack = 999
		definitions[item.item_id] = item

func get_definition(id: StringName) -> Item:
	return definitions.get(id)
#endregion
