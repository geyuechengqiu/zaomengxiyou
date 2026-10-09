extends C_Inventory
class_name OriginalInventory
#region 原版四类独立容量，25格分页；运行实例与资源定义分离
signal operation_rejected(message: String)
signal item_used(item: Item, count: int)
signal currency_changed(spirit: int)
@export var initial_items: Array[Item] = []
@export var original_rules: JSON
@export var bag_capacities: Dictionary[String, int] = {"equipment": 25, "material": 25, "consumable": 25, "fashion": 25}
@export var role_condition: int = 1
@export var allow_battle_changes: bool = true
var spirit: int = 0
var _serial: int = 0
var _aliases: Dictionary = {}
const PAGE_SIZE := 25
const MAX_BAG_CAPACITY := 500

func _ready() -> void:
	MAX_SLOT_COUNT = 4 * MAX_BAG_CAPACITY
	equip_slots = {"armor": [Equip.EQUIP_TYPE.CHEST, null], "helmet": [Equip.EQUIP_TYPE.HEAD, null], "weapon": [Equip.EQUIP_TYPE.WEAPON, null], "ornament": [Equip.EQUIP_TYPE.NECKLACE, null], "wing": [-1,null], "amulet": [-1,null], "fashionWeapon": [-1,null], "fashionHelmet": [-1,null], "fashionArmor": [-1,null], "fairy": [-1,null], "title": [-1,null]}
	bag_capacities = bag_capacities.duplicate()
	for key in bag_capacities: bag_capacities[key] = clampi(bag_capacities[key],1,MAX_BAG_CAPACITY)
	super._ready()
	for definition in initial_items: add_item(definition)
	# 属性组件在实体初始化阶段绑定；槽位配置完成后重新通知统一入口。
	for slot in equip_slots: equip_changed.emit(slot, null)

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
	result.sort_custom(func(a: Item, b: Item):
		var aq := int(a.original_data.get("quality", 0))
		var bq := int(b.original_data.get("quality", 0))
		if aq != bq: return aq > bq
		if a.item_id != b.item_id: return String(a.item_id).naturalnocasecmp_to(String(b.item_id)) < 0
		return a.runtime_id < b.runtime_id)
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
	if definition == null or definition.quantity <= 0: return
	var key := get_bag_key(definition)
	var bag := get_bag_items(key)
	var space := maxi(0, bag_capacities.get(key, 25) - bag.size()) * maxi(1, definition.max_stack)
	for item in bag:
		if item.can_merge_with(definition): space += item.max_stack - item.quantity
	if space < definition.quantity:
		operation_rejected.emit("背包已满")
		return
	var copy := definition.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as Item
	copy.original_data = definition.original_data.duplicate(true)
	_serial += 1
	copy.runtime_id = _serial
	_aliases[definition.get_instance_id()] = copy
	for item in bag:
		if item.can_merge_with(copy): item.merge(copy)
		if copy.quantity == 0:
			_aliases[definition.get_instance_id()] = item
			item_changed.emit()
			return
	items[get_empty_index()] = copy
	item_changed.emit()

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
	equip_changed.emit(slot, item)
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
	equip_changed.emit(slot, null)
	item_changed.emit()

func _can_change(item: Item) -> bool:
	if not allow_battle_changes or int(item.original_data.get("isCanChangeInBattle", 1)) == 0:
		operation_rejected.emit("战斗中不能操作此物品")
		return false
	return true
#endregion
#region 使用、出售与锁定；没有原版效果实现的物品不假扣数量
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
	if item == null: return
	item.locked = not item.locked
	item_changed.emit()

func pack_items() -> void:
	merge_similar_items()
	item_changed.emit()
#endregion
