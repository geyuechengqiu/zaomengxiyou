extends MarginContainer
class_name ItemSlot
#region 配置与运行状态

@onready var color_rect: ColorRect = %ColorRect
@onready var item_tile: MarginContainer = $item_tile

var item : Item = null : set = _item_setter
#endregion
#region 信号

signal mouse_button_left_pressed
signal mouse_button_right_pressed
#endregion
#region 生命周期与引擎回调

func _ready() -> void:
	self.gui_input.connect(_on_gui_input)
	color_rect.visible = false
#endregion
#region 公共接口

## 选中道具槽
func selected() -> void:
	color_rect.color = Color.WHITE
	color_rect.visible = true

## 取消选中道具槽
func disselected() -> void:
	#color_rect.color = Color.BLACK
	color_rect.visible = false
#endregion
#region 信号回调

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed() :
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_button_left_pressed.emit()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			mouse_button_right_pressed.emit()
#endregion
#region 内部实现

func _item_setter(value : Item) -> void:
	item = value
	if item != null:
		item_tile.update_display(item)
		item_tile.show()
	else:
		item_tile.hide()	
#endregion
