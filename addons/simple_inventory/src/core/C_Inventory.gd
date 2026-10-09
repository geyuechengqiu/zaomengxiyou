extends Node
class_name C_Inventory
#region 配置与运行状态

## 存放道具ItemResource的数组
@export_storage var items : Array[Item] = []
## 装备槽: 对应名称，唯一ID, 值包括装备类型和对应装备
@export var equip_slots : Dictionary[String, Array] = {
	"chest" : [Equip.EQUIP_TYPE.CHEST, null], 
	"feet" : [Equip.EQUIP_TYPE.FEET, null], 
	"head" : [Equip.EQUIP_TYPE.HEAD, null], 
	"legs" : [Equip.EQUIP_TYPE.LEGS, null],
	"necklace" : [Equip.EQUIP_TYPE.NECKLACE, null], 
	"weapon" : [Equip.EQUIP_TYPE.WEAPON, null], 
	"ring1" : [Equip.EQUIP_TYPE.RING, null], 
	"ring2" : [Equip.EQUIP_TYPE.RING, null], 
	"ring3" : [Equip.EQUIP_TYPE.RING, null], 
}

## 槽上限
@export var MAX_SLOT_COUNT := 20
#endregion
#region 信号

## 道具变化时发出此信号
signal item_changed
signal equip_changed(equip_slot_name : StringName, equip : Equip)
#endregion
#region 生命周期与引擎回调

func _ready() -> void:
	equip_slots = equip_slots.duplicate(true)
	items.resize(MAX_SLOT_COUNT)
#endregion
#region 公共接口

## 添加道具
func add_item(item: Item) -> void:
	var index = get_empty_index()
	if index != -1:
		items[index] = item
		item_changed.emit()

## 删除道具
func remove_item(remove_item: Item) -> void:
	if not remove_item : return
	var index :int = 0
	for item in items:
		if item == remove_item:
			items[index] = null
		index += 1
	item_changed.emit()

## 获取道具
func get_item(index: int) -> Item:
	return items[index] if index >= 0 and index < items.size() else null

## 获取空的索引
func get_empty_index() -> int:
	for index in items.size():
		if items[index] == null:
			return index
	return -1

## 背包整理
func pack_items():
	# 先合并相同道具，然后按类型排序，最后优化空格
	merge_similar_items()
	sort_items_by_type()
	item_changed.emit()

## 合并相同道具
func merge_similar_items():
	var temp_items = items.duplicate()
	for i in range(temp_items.size()):
		var item : Item = temp_items[i]
		if item == null or item.is_stack_maxed():
			continue
		for j in range(i + 1, temp_items.size()):
			var other_item : Item = temp_items[j]
			if other_item != null and item.can_merge_with(other_item):
				# 检查堆叠上限
				item.merge(other_item)
				if other_item.quantity <= 0:
					temp_items[j] = null
	items = temp_items.filter(func(i): return i != null)
	items.resize(MAX_SLOT_COUNT)

## 按类型排序
func sort_items_by_type():
	var temp_items = items.filter(func(item): return item != null)
	temp_items.sort_custom(
		func(a, b):
			return a.category < b.category
	)
	items = temp_items
	items.resize(MAX_SLOT_COUNT)

## 使用道具
func use_item(item : Item) -> void:
	if item != null and item is Equip and item.category == Item.ITEM_TYPE.EQUIPMENT:
		equip_item(item)

## 装备道具
func equip_item(equip : Equip) -> void:
	if equip == null or not items.has(equip) or _get_equip_slot_name(equip).is_empty(): return
	items[items.find(equip)] = null
	var empty_slot : StringName = _get_empty_equip_slot_name(equip)
	if empty_slot == "":
		# 没有空装备位
		var slot : StringName = _get_equip_slot_name(equip)
		var old_equip : Equip = equip_slots[slot][1]
		equip_slots[slot][1] = equip
		add_item(old_equip)
		equip_changed.emit(slot, equip)
	else:
		equip_slots[empty_slot][1] = equip
		equip_changed.emit(empty_slot, equip)
	item_changed.emit()

## 卸载装备
func unequip_item(equip : Equip) -> void:
	if equip == null or _get_equip_slot(equip).is_empty(): return
	if get_empty_index() == -1 : return
	var slot : StringName = _get_equip_slot(equip)
	equip_slots[slot][1] = null
	equip_changed.emit(slot, null)
	add_item(equip)
#endregion
#region 内部实现

## 获取装备所在的装备槽
func _get_equip_slot(equip : Equip) -> StringName:
	for slot_name in equip_slots.keys():
		var slot_equip : Equip = equip_slots[slot_name][1]
		if equip == slot_equip:
			return slot_name
	return ""

## 获取第一个类型匹配的装备槽
func _get_equip_slot_name(equip : Equip) -> StringName:
	var equip_type : Equip.EQUIP_TYPE = equip.equip_type
	for slot_name in equip_slots.keys():
		var slot_type : Equip.EQUIP_TYPE = equip_slots[slot_name][0]
		if slot_type == equip_type:
			return slot_name
	return ""

## 获得空装备槽
func _get_empty_equip_slot_name(equip : Equip) -> StringName:
	var equip_type : Equip.EQUIP_TYPE = equip.equip_type
	for slot_name in equip_slots.keys():
		var slot_type : Equip.EQUIP_TYPE = equip_slots[slot_name][0]
		var slot_equip : Equip = equip_slots[slot_name][1]
		if slot_type == equip_type and slot_equip == null:
			return slot_name
	return ""
#endregion
