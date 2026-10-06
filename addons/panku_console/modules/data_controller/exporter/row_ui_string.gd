extends "./row_ui.gd"
#region 配置与运行状态

@export var line_edit:LineEdit
#endregion
#region 公共接口

func get_ui_val() -> String: 
	return line_edit.text

func update_ui(val:String):
	line_edit.text = val

func is_active() -> bool:
	return line_edit.has_focus()
#endregion
#region 生命周期与引擎回调

func _ready():
	line_edit.text_submitted.connect(
		func(_s):
			ui_val_changed.emit(get_ui_val())
	)
	line_edit.focus_exited.connect(
		func():
			ui_val_changed.emit(get_ui_val())
	)
#endregion
