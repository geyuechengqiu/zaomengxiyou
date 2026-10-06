@tool
extends ItemSlot
class_name EquipSlot
#region 类型与常量

const EQUIP_SLOT_TEXTURE : Array[Texture2D] = [
	preload("res://addons/simple_inventory/assets/textures/equip_slot/chest_slot.tres"), 			# chest
	preload("res://addons/simple_inventory/assets/textures/equip_slot/feet_slot.tres"),			# feet
	preload("res://addons/simple_inventory/assets/textures/equip_slot/head_slot.tres"), 			# head
	preload("res://addons/simple_inventory/assets/textures/equip_slot/legs_slot.tres"), 			# legs
	preload("res://addons/simple_inventory/assets/textures/equip_slot/necklace_slot.tres"), 			# necklace
	preload("res://addons/simple_inventory/assets/textures/equip_slot/ring_slot.tres"), 			# ring
	preload("res://addons/simple_inventory/assets/textures/equip_slot/weapon_slot.tres") 			# weapon
]
#endregion
#region 配置与运行状态

@onready var tr_slot: TextureRect = $MarginContainer/tr_slot
@export var equip_slot_name : StringName = ""
@export var equip_type : Equip.EQUIP_TYPE = Equip.EQUIP_TYPE.CHEST :
	set(value):
		equip_type = value
		if tr_slot:
			_display_equip_slot()
#endregion
#region 生命周期与引擎回调

func _ready() -> void:
	_display_equip_slot()
	super()
#endregion
#region 内部实现

func _display_equip_slot() -> void:
	var slot_index : int = equip_type
	tr_slot.texture = EQUIP_SLOT_TEXTURE[slot_index]

func _item_setter(value : Item) -> void:
	tr_slot.visible = value == null
	super(value)
#endregion
