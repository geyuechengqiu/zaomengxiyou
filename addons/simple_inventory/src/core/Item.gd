extends Resource
class_name Item
#region 类型与常量

enum ITEM_TYPE {
	NONE,
	CONSUMABLE,	## 消耗品
	EQUIPMENT,	## 装备
	MATERIAL,	## 材料
}
# const ITEM_TYPE_CONST : Dictionary = {
	#"NONE" : 0,
	#"CONSUMABLE": 1,	# 消耗品
	#"EQUIPMENT": 2,	# 装备
	#"MATERIAL": 3,	# 材料
#endregion
#region 配置与运行状态
#}

# Item的属性
@export var name = "道具名称"
@export var icon: Texture = null
## 原版Resource.icon1地面图标与icon2背包图标分别保存。
@export var pickup_icon: Texture2D
@export var description = "道具描述"
## 道具类型
@export var category : ITEM_TYPE = ITEM_TYPE.NONE # 如 "consumable", "equipment", "material" 等
@export var max_stack := 1
@export var quantity = 1 : 
	set(value):
		quantity_changed.emit(value)
		quantity = clamp(value, 0, max_stack)
@export var weight = 0
@export var attributes : Dictionary[String, float] = {} # 存储属性如 {"strength": 10, "health": 50}
@export_group("Original Game Definition")
## 原版定义只读；放入OriginalInventory时复制为独立运行实例。
@export var item_id: StringName
@export var original_data: Dictionary = {}
var runtime_id: int = 0
var locked: bool = false
## 资源文件是定义；create_instance生成的物品才拥有独立运行状态。
var definition: Item
var runtime: InventoryItemState

func create_instance() -> Item:
	var source: Item = definition if definition != null else self
	var copy := source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as Item
	copy.definition = source
	copy.quantity = quantity
	copy.locked = locked
	copy.runtime = InventoryItemState.from_dictionary(runtime.to_dictionary()) if runtime != null else InventoryItemState.new()
	copy.runtime.unique_id = Crypto.new().generate_random_bytes(16).hex_encode()
	copy.runtime.owner_inventory_id = 0
	return copy

func get_save_data() -> Dictionary:
	return {"item_id": String(item_id), "quantity": quantity, "locked": locked, "state": runtime.to_dictionary() if runtime != null else {}}
#endregion
#region 信号

signal quantity_changed(value: int)
#endregion
#region 公共接口

## 是否达到堆叠上限
func is_stack_maxed() -> bool:
	return self.quantity >= self.max_stack

## 道具合并
func merge(other_item: Item) -> bool:
	if self.can_merge_with(other_item) and not self.is_stack_maxed():
		var total_quantity = self.quantity + other_item.quantity
		self.quantity = min(total_quantity, self.max_stack)
		other_item.quantity = max(0, total_quantity - self.max_stack)
#		print("合并道具：", self.quantity, ":", other_item.quantity)
#		if other_item.quantity == 0:
#			other_item.free()
		return true
	return false

## 能否合并
func can_merge_with(other_item: Item) -> bool:
	return other_item != null and max_stack > 1 and category == other_item.category and item_id == other_item.item_id and name == other_item.name and attributes == other_item.attributes and original_data == other_item.original_data and locked == other_item.locked and _growth_key() == other_item._growth_key()

func _growth_key() -> Dictionary:
	var key := runtime.to_dictionary() if runtime != null else InventoryItemState.new().to_dictionary()
	key.erase("unique_id")
	return key
#endregion
