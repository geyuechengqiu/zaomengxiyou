extends HBoxContainer
#region 信号

signal exp_edit_submitted(new_exp:String)
#endregion
#region 配置与运行状态

@export var exp_edit:LineEdit
@export var remap_button:Button
@export var delete_button:Button
#endregion
#region 生命周期与引擎回调

func _ready():
	delete_button.pressed.connect(queue_free)
	exp_edit.text_submitted.connect(
		func(new_text:String):
			exp_edit.release_focus()
			exp_edit_submitted.emit(new_text)
	)
	exp_edit.focus_exited.connect(
		func():
			exp_edit_submitted.emit(exp_edit.text)
	)
#endregion
