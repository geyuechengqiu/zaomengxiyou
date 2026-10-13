extends C_Inventory
class_name OriginalInventory
#region 原版四类独立容量，25格分页；运行实例与资源定义分离
signal operation_rejected(message: String)
signal item_used(item: Item, count: int)
signal currency_changed(spirit: int)
signal operation_completed(message: String)
signal wardrobe_requested
signal appearance_changed
signal equipment_changed(change: Dictionary)
signal growth_completed(item: Item, operation: StringName)
signal display_name_changed(value: String)
@export_group("Player Presentation")
## 本地展示编号由业务填写，不能用战斗实体ID冒充账户编号。
@export var player_number: String = ""
@export var display_name: String = "local"
@export var presentation_rules: JSON
@export_group("Inventory")
@export var initial_items: Array[Item] = []
@export var original_rules: JSON
@export var bag_capacities: Dictionary[String, int] = {"equipment": 25, "material": 25, "consumable": 25, "fashion": 25}
@export var role_condition: int = 1
@export var allow_battle_changes: bool = true
@export var growth_rules: JSON
@export var equipment_sets: Array[InventoryEquipmentSet] = []
@export_range(0, 1000000000) var initial_spirit: int = 0
var spirit: int = 0
var show_fashion: bool = true
var _serial: int = 0
var _aliases: Dictionary = {}
const PAGE_SIZE := 25
const MAX_BAG_CAPACITY := 500
const BAG_POLICY := preload("res://addons/simple_inventory/src/core/InventoryBagPolicy.cs")
var _bag_policy = BAG_POLICY.new()

func _ready() -> void:
	set_display_name(display_name)
	spirit = initial_spirit
	MAX_SLOT_COUNT = 4 * MAX_BAG_CAPACITY
	equip_slots = {"armor": [Equip.EQUIP_TYPE.CHEST, null], "helmet": [Equip.EQUIP_TYPE.HEAD, null], "weapon": [Equip.EQUIP_TYPE.WEAPON, null], "ornament": [Equip.EQUIP_TYPE.NECKLACE, null], "wing": [-1,null], "amulet": [-1,null], "fashionWeapon": [-1,null], "fashionHelmet": [-1,null], "fashionArmor": [-1,null], "fairy": [-1,null], "title": [-1,null]}
	bag_capacities = bag_capacities.duplicate()
	for key in bag_capacities: bag_capacities[key] = clampi(bag_capacities[key],1,MAX_BAG_CAPACITY)
	super._ready()
	for definition in initial_items: add_item(definition)
	# 属性组件在实体初始化阶段绑定；槽位配置完成后重新通知统一入口。
	for slot in equip_slots: equip_changed.emit(slot, null)
	_notify_equipment(&"initialize")

func get_bag_key(item: Item) -> String:
	if String(item.original_data.get("type", "")) == "fashion": return "fashion"
	match item.category:
		Item.ITEM_TYPE.EQUIPMENT: return "equipment"
		Item.ITEM_TYPE.CONSUMABLE: return "consumable"
	return "material"

func _get_equip_slot_name(item: Equip) -> StringName:
	var part := StringName(item.original_data.get("part", ""))
	if not part.is_empty(): return part if equip_slots.has(part) else &""
	return {Equip.EQUIP_TYPE.CHEST:&"armor",Equip.EQUIP_TYPE.HEAD:&"helmet",Equip.EQUIP_TYPE.WEAPON:&"weapon",Equip.EQUIP_TYPE.NECKLACE:&"ornament"}.get(item.equip_type, &"")

func get_bag_items(key: String) -> Array[Item]:
	var result: Array[Item] = []
	for item in items:
		if item != null and get_bag_key(item) == key: result.append(item)
	result.assign(_bag_policy.sort_items(result))
	return result

func get_page_count(key: String) -> int:
	return maxi(1, mini(MAX_BAG_CAPACITY, bag_capacities.get(key, 25) + PAGE_SIZE) / PAGE_SIZE)

func get_extension_quote(key: String, target_capacity: int) -> Dictionary:
	if original_rules == null or not bag_capacities.has(key) or target_capacity <= bag_capacities[key] or target_capacity > MAX_BAG_CAPACITY: return {}
	var pack_type := {"equipment":1,"material":2,"consumable":3,"fashion":4}
	var costs: Dictionary = {}
	for index in range(bag_capacities[key]+1,target_capacity+1):
		var id := str(pack_type[key]*1000+index)
		var rule: Dictionary = original_rules.data.open_pack.get(id,{})
		if rule.is_empty() or rule.consume_type != "item": return {}
		var item_id := StringName(str(int(rule.consume_subType)))
		costs[item_id] = costs.get(item_id,0)+int(rule.consume_count)
	return {"bag":key,"capacity":target_capacity,"costs":costs}

func extend_bag(key: String, target_capacity: int) -> bool:
	var quote := get_extension_quote(key,target_capacity)
	if quote.is_empty():
		operation_rejected.emit("背包格无法解锁")
		return false
	for id in quote.costs:
		var count := 0
		for item in items:
			if item != null and item.item_id == id and not item.locked: count += item.quantity
		if count < quote.costs[id]:
			operation_rejected.emit("扩容物品不足")
			return false
	# 所有物品先验证，之后原子扣除；中途不通知界面半完成状态。
	for id in quote.costs:
		var remaining: int = quote.costs[id]
		for index in range(items.size()):
			var item := items[index]
			if item == null or item.item_id != id or item.locked: continue
			var consumed := mini(remaining,item.quantity)
			item.quantity -= consumed
			remaining -= consumed
			if item.quantity == 0: items[index] = null
			if remaining == 0: break
	bag_capacities[key] = target_capacity
	item_changed.emit()
	return true

func get_owned_item(item: Item) -> Item:
	if item == null: return null
	if items.has(item): return item
	for slot in equip_slots:
		if equip_slots[slot][1] == item: return item
	var owned := _aliases.get(item.get_instance_id()) as Item
	if owned != null:
		if items.has(owned): return owned
		for slot in equip_slots:
			if equip_slots[slot][1] == owned: return owned
	return null

func add_item(definition: Item) -> void:
	try_add_item(definition)

## 全量入库或完全拒绝；世界掉落用返回值决定是否移除。
func try_add_item(definition: Item, notify_errors: bool = true) -> bool:
	if definition == null or definition.quantity <= 0: return false
	if definition.runtime != null and definition.runtime.owner_inventory_id != 0:
		if notify_errors: operation_rejected.emit("物品已属于背包，不能重复拾取")
		return false
	var key := get_bag_key(definition)
	var bag := get_bag_items(key)
	var space := maxi(0, bag_capacities.get(key, 25) - bag.size()) * maxi(1, definition.max_stack)
	for item in bag:
		if item.can_merge_with(definition): space += item.max_stack - item.quantity
	if space < definition.quantity:
		if notify_errors: operation_rejected.emit("背包已满")
		return false
	var copy: Item = definition if definition.runtime != null else definition.create_instance()
	copy.runtime.owner_inventory_id = get_instance_id()
	_serial += 1
	copy.runtime_id = _serial
	_aliases[definition.get_instance_id()] = copy
	for item in bag:
		if item.can_merge_with(copy): item.merge(copy)
		if copy.quantity == 0:
			_aliases[definition.get_instance_id()] = item
			item_changed.emit()
			return true
	items[get_empty_index()] = copy
	item_changed.emit()
	return true

func equip_item(candidate: Equip) -> void:
	var item := get_owned_item(candidate) as Equip
	if item == null or not items.has(item): return
	var requirement := int(item.original_data.get("roleConditions", 0))
	if requirement != 0 and requirement != role_condition:
		operation_rejected.emit("该角色无法装备此物品")
		return
	var actor := get_parent() as BattleEntity2D
	if actor != null and actor.attributes.current_level < int(item.original_data.get("userLevel", 1)):
		operation_rejected.emit("等级不足")
		return
	if not _can_change(item): return
	var slot := _get_equip_slot_name(item)
	if slot.is_empty():
		operation_rejected.emit("此装备暂未开放对应装备位")
		return
	var index := items.find(item)
	var previous := equip_slots[slot][1] as Equip
	# 原子交换：旧装备直接回到腾出的格子，背包满时也不会丢失或复制。
	items[index] = previous
	equip_slots[slot][1] = item
	_notify_equipment(&"equip", slot, item)
	item_changed.emit()

func unequip_item(candidate: Equip) -> void:
	var item := get_owned_item(candidate) as Equip
	if item == null or not _can_change(item): return
	var slot := _get_equip_slot(item)
	if slot.is_empty(): return
	if get_bag_items(get_bag_key(item)).size() >= bag_capacities.get(get_bag_key(item), 25):
		operation_rejected.emit("背包已满")
		return
	items[get_empty_index()] = item
	equip_slots[slot][1] = null
	_notify_equipment(&"unequip", slot, null)
	item_changed.emit()

func _can_change(item: Item) -> bool:
	if not allow_battle_changes or int(item.original_data.get("isCanChangeInBattle", 1)) == 0:
		operation_rejected.emit("战斗中不能操作此物品")
		return false
	return true
#endregion
#region 使用、出售与锁定；没有原版效果实现的物品不假扣数量
func get_item_attribute_values(item: Item) -> Dictionary:
	var result: Dictionary = {}
	if item == null: return result
	for modifier in get_item_attribute_modifiers(item):
		result[modifier.attribute_id] = float(result.get(modifier.attribute_id, 0.0)) + modifier.value
	return result

func get_item_attribute_modifiers(item: Item) -> Array[GameplayAttributeModifier]:
	var result: Array[GameplayAttributeModifier] = []
	if item == null: return result
	if item is BattleInventoryEquipment and item.battle_definition != null:
		for template in item.battle_definition.attribute_modifiers:
			var modifier := template.duplicate() as GameplayAttributeModifier
			if item.runtime != null and modifier.modifier_type == GameplayAttributeModifier.ModifierType.ADD:
				modifier.value = float(item.runtime.rolled_attributes.get(String(modifier.attribute_id), modifier.value))
			result.append(modifier)
	else:
		for id in item.attributes: result.append(GameplayAttributeModifier.new(StringName(id), item.attributes[id]))
	if item.runtime != null:
		var existing := {}
		for modifier in result: existing[String(modifier.attribute_id)] = true
		for id in item.runtime.rolled_attributes:
			if not existing.has(String(id)): result.append(GameplayAttributeModifier.new(StringName(id), float(item.runtime.rolled_attributes[id])))
		var level := item.runtime.enhancement_level
		if String(item.original_data.get("type", "")) == "fashion": level %= 6
		if String(item.original_data.get("part", "")) != "amulet":
			for key in item.original_data:
				if String(key).ends_with("Add"):
					var amount := floorf(float(item.original_data[key]) * level + 0.5001)
					if amount != 0.0: result.append(GameplayAttributeModifier.new(StringName(String(key).trim_suffix("Add")), amount))
		for values: Dictionary in [item.runtime.random_affixes, item.runtime.additional_attributes]:
			for id in values: result.append(GameplayAttributeModifier.new(StringName(id), float(values[id])))
	return result

func _notify_equipment(reason: StringName, slot: StringName = &"", item: Equip = null) -> void:
	equipment_changed.emit({"reason": reason, "slot": slot, "item": item, "sets": get_active_set_bonuses()})
	if not slot.is_empty(): equip_changed.emit(slot, item)
	appearance_changed.emit()

func get_active_set_bonuses() -> Dictionary:
	var result := {}
	var equipped_ids := {}
	var fashion_counts := {}
	for slot in equip_slots:
		var item := equip_slots[slot][1] as Item
		if item == null: continue
		equipped_ids[item.item_id] = true
		var set_id := str(int(item.original_data.get("fashionSuitId", 0)))
		if set_id != "0": fashion_counts[set_id] = int(fashion_counts.get(set_id, 0)) + 1
	for definition_set in equipment_sets:
		if definition_set == null or definition_set.set_id.is_empty(): continue
		var count := 0
		for id in definition_set.item_ids:
			if equipped_ids.has(id): count += 1
		for index in range(definition_set.bonuses.size()):
			var bonus: Dictionary = definition_set.bonuses[index]
			if count >= int(bonus.get("pieces", 10000)):
				result["%s/%d" % [definition_set.set_id, index]] = bonus.get("attributes", {}).duplicate(true)
	if growth_rules != null:
		for set_id in fashion_counts:
			var rule: Dictionary = growth_rules.data.get("fashion_sets", {}).get(set_id, {})
			var thresholds := String(rule.get("fashionNum", "")).split(";", false)
			var names := String(rule.get("attr", "")).split(";", false)
			var values := String(rule.get("value", "")).split(";", false)
			for index in range(mini(thresholds.size(), mini(names.size(), values.size()))):
				if int(fashion_counts[set_id]) < int(thresholds[index]): continue
				var ids := names[index].split(",")
				var amounts := values[index].split(",")
				var attrs := {}
				for attr_index in range(mini(ids.size(), amounts.size())): attrs[ids[attr_index]] = float(amounts[attr_index])
				result["fashion.%s/%d" % [set_id, index]] = attrs
	return result

func grant_spirit(amount: int) -> bool:
	if amount < 0: return false
	spirit += amount
	currency_changed.emit(spirit)
	return true

func get_growth_quote(candidate: Item, operation: StringName) -> Dictionary:
	var item := get_owned_item(candidate)
	if not item is Equip or item.runtime == null or growth_rules == null: return {}
	var record: Dictionary = {}
	if operation == &"enhance":
		if item.runtime.enhancement_level >= int(item.original_data.get("refineMax", 0)): return {}
		var id := str(int(item.original_data.get("series", 0)) * 1000 + item.runtime.enhancement_level + 1)
		record = growth_rules.data.get("refine", {}).get(id, {})
	elif operation == &"reroll" and int(item.original_data.get("isReset", 0)) != 0:
		record = growth_rules.data.get("reset", {}).get(String(item.item_id), {})
	if record.is_empty(): return {}
	var kinds := String(record.get("consume_type", "")).split(";")
	var ids := String(record.get("consume_subType", "")).split(";")
	var counts := String(record.get("consume_count", "")).split(";")
	if kinds.size() != ids.size() or ids.size() != counts.size(): return {}
	var groups: Array[Dictionary] = []
	var currency := 0
	for index in range(kinds.size()):
		if kinds[index] == "coin" and ids[index] == "spirit": currency += int(counts[index])
		elif kinds[index] == "item":
			if ids[index].contains(","):
				var sub_ids := ids[index].split(",")
				var sub_counts := counts[index].split(",")
				if sub_ids.size() != sub_counts.size(): return {}
				for sub in range(sub_ids.size()): groups.append({"ids": [sub_ids[sub]], "count": int(sub_counts[sub])})
			else: groups.append({"ids": Array(ids[index].split("+")), "count": int(counts[index])})
		else: return {}
	return {"operation": operation, "spirit": currency, "groups": groups}

func apply_growth(candidate: Item, operation: StringName) -> bool:
	var item := get_owned_item(candidate)
	var quote := get_growth_quote(item, operation)
	if quote.is_empty(): operation_rejected.emit("此装备不支持该成长操作或已达上限"); return false
	if not _can_change(item): return false
	if spirit < int(quote.spirit): operation_rejected.emit("灵魂不足"); return false
	# 验证所有成本后再扣除，重复材料需求共享剩余数；失败不部分扣款。
	var plan := {}
	for group: Dictionary in quote.groups:
		var remaining := int(group.count)
		if remaining <= 0: return false
		for index in range(items.size()):
			var material := items[index]
			if material == null or material.locked or not group.ids.has(String(material.item_id)): continue
			var used := mini(remaining, material.quantity - int(plan.get(index, 0)))
			plan[index] = int(plan.get(index, 0)) + used
			remaining -= used
			if remaining == 0: break
		if remaining > 0: operation_rejected.emit("强化或洗练材料不足"); return false
	var actor := get_parent() as BattleEntity2D
	if operation == &"reroll" and (actor == null or not _has_random_ranges(item)): return false
	for index in plan:
		items[index].quantity -= int(plan[index])
		if items[index].quantity == 0: items[index] = null
	spirit -= int(quote.spirit)
	if operation == &"enhance": item.runtime.enhancement_level += 1
	else: roll_equipment_attributes(item, actor.session.random)
	_notify_equipment(operation, _get_equip_slot(item as Equip), item as Equip)
	currency_changed.emit(spirit)
	item_changed.emit()
	growth_completed.emit(item, operation)
	operation_completed.emit("强化成功" if operation == &"enhance" else "洗练完成")
	return true

func _has_random_ranges(item: Item) -> bool:
	for id in OriginalItemPresenter.ATTRIBUTE_NAMES:
		if String(item.original_data.get(String(id), "")).contains(";"): return true
	return false

## 掉落与洗练共用原Equipment属性区间；独立命名流不消耗伤害随机数。
func roll_equipment_attributes(item: Item, rng: BattleRandom) -> void:
	if not item is Equip or item.runtime == null: return
	for id in OriginalItemPresenter.ATTRIBUTE_NAMES:
		var bounds := String(item.original_data.get(String(id), "")).split(";", false)
		if bounds.size() == 2 and bounds[0].is_valid_float() and bounds[1].is_valid_float():
			item.runtime.rolled_attributes[String(id)] = rng.random_int(ceili(float(bounds[0])), floori(float(bounds[1])), &"equipment.roll")

## GM/任务附加属性替换同一实例来源，不能直接写角色最终值。
func set_item_additions(candidate: Item, values: Dictionary, affixes: bool = false) -> bool:
	var item := get_owned_item(candidate)
	if not item is Equip or item.runtime == null: return false
	for id in values:
		if not OriginalItemPresenter.ATTRIBUTE_NAMES.has(StringName(id)) or not is_finite(float(values[id])): return false
	if affixes: item.runtime.random_affixes = values.duplicate(true)
	else: item.runtime.additional_attributes = values.duplicate(true)
	_notify_equipment(&"attributes", _get_equip_slot(item as Equip), item as Equip)
	item_changed.emit()
	return true

func set_show_fashion(enabled: bool) -> void:
	if show_fashion == enabled: return
	show_fashion = enabled
	appearance_changed.emit()
	item_changed.emit()

func get_equipment_appearance(part: StringName) -> StringName:
	var fashion_part: StringName = {&"weapon":&"fashionWeapon", &"helmet":&"fashionHelmet", &"armor":&"fashionArmor"}.get(part, &"")
	var candidate: BattleInventoryEquipment = equip_slots.get(String(fashion_part), [null, null])[1] as BattleInventoryEquipment if show_fashion else null
	var actor := get_parent() as BattleEntity2D
	var character_id: StringName = actor.definition_id if actor != null else &""
	if candidate == null or candidate.get_appearance_skin(character_id).is_empty(): candidate = equip_slots.get(String(part), [null, null])[1] as BattleInventoryEquipment
	return candidate.get_appearance_skin(character_id) if candidate != null else &""

func get_comparison_item(item: Item) -> Item:
	if not item is Equip: return null
	var slot := _get_equip_slot_name(item as Equip)
	var equipped := equip_slots.get(String(slot), [null, null])[1] as Item
	return equipped if equipped != item else null

func get_context_actions(candidate: Item, equipped: bool) -> Array[Dictionary]:
	var item := get_owned_item(candidate)
	var result: Array[Dictionary] = []
	if item == null: return result
	var can_change := allow_battle_changes and int(item.original_data.get("isCanChangeInBattle", 1)) != 0
	if equipped:
		# 原菜单第6帧是分解；卸下使用同字体文本，避免显示错误操作。
		result.append({"id":&"use", "text":"卸下", "frame":0, "enabled":can_change})
	else:
		result.append({"id":&"use", "text":"装备" if item is Equip else "使用", "frame":1 if item is Equip else 3, "enabled":can_change and (item is Equip or int(item.original_data.get("isUse", 0)) != 0)})
		result.append({"id":&"sell", "text":"出售", "frame":2, "enabled":can_change and not item.locked and int(item.original_data.get("isSell", 1)) != 0})
	if item is Equip: result.append({"id":&"lock", "text":"解锁" if item.locked else "锁定", "frame":23 if item.locked else 22, "enabled":can_change})
	return result

func set_display_name(value: String) -> void:
	var next_name := value.left(15)
	if display_name == next_name: return
	display_name = next_name
	display_name_changed.emit(display_name)

func request_wardrobe() -> void:
	# 衣柜与时装装备位切换是两个独立功能；业务模块从此信号接入。
	wardrobe_requested.emit()
	if wardrobe_requested.get_connections().is_empty(): operation_rejected.emit("衣柜模块尚未接入")

func use_item(candidate: Item) -> void:
	var item := get_owned_item(candidate)
	if item == null or not items.has(item): return
	if item is Equip and item.category == Item.ITEM_TYPE.EQUIPMENT:
		equip_item(item)
		return
	if not _can_change(item): return
	if int(item.original_data.get("isUse", 0)) == 0:
		operation_rejected.emit("此物品不可直接使用")
		return
	var actor := get_parent() as BattleEntity2D
	var applied := false
	if actor != null:
		for index in range(1, 4):
			var kind := String(item.original_data.get("attributeT%d" % index, ""))
			var raw := str(item.original_data.get("attributeV%d" % index, "0"))
			var amount := raw.to_float() if raw.is_valid_float() else 0.0
			var vital_id: StringName = &"health" if kind == "hp" else &"mana"
			if kind in ["hp", "mp"] and amount > 0:
				var vital := actor.attributes.get_vital(vital_id)
				if vital != null and vital.current_value < vital.get_max_value():
					vital.set_current_value(vital.current_value + amount)
					applied = true
	if not applied:
		operation_rejected.emit("当前无法使用此物品")
		return
	item.quantity -= 1
	if item.quantity == 0: items[items.find(item)] = null
	item_used.emit(item, 1)
	item_changed.emit()

func sell_item(candidate: Item, count: int = 1) -> bool:
	var item := get_owned_item(candidate)
	if item == null or not items.has(item) or count <= 0 or count > item.quantity: return false
	if not _can_change(item): return false
	if item.locked or int(item.original_data.get("isSell", 1)) == 0:
		operation_rejected.emit("此物品已锁定或不可出售")
		return false
	var price := get_sell_price(item)
	spirit += price * count
	item.quantity -= count
	if item.quantity == 0: items[items.find(item)] = null
	currency_changed.emit(spirit)
	item_changed.emit()
	return true

func get_sell_price(item: Item) -> int:
	var discount: float = float(original_rules.data.sell_discount) if original_rules != null else 0.2
	return maxi(0, floori(float(item.original_data.get("price",0))*discount))

func toggle_lock(candidate: Item) -> void:
	var item := get_owned_item(candidate)
	if not item is Equip or not _can_change(item): return
	item.locked = not item.locked
	item_changed.emit()

func pack_items() -> void:
	merge_similar_items()
	item_changed.emit()
#endregion
