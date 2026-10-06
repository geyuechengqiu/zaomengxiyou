class_name PankuButton extends Control
#region 信号

signal pressed
signal button_down
signal button_up
#endregion
#region 配置与运行状态

@export
var button:Button

@export
var trect:TextureRect

@export
var label:Label

var icon:
	set(v):
		trect.texture = v
	get:
		return trect.texture

var text:
	set(v):
		label.text = v
	get:
		return label.text
#endregion
#region 生命周期与引擎回调

func _ready():
	
	button.pressed.connect(
		func():
			pressed.emit()
	)
	button.button_down.connect(
		func(): button_down.emit()
	)
	button.button_up.connect(
		func(): button_up.emit()
	)
#endregion
