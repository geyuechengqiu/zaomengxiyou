extends "./row_ui.gd"
#region 配置与运行状态

@export var opt_btn:OptionButton
#endregion
#region 公共接口

func update_ui(val):
	opt_btn.select(val)

func is_active():
	return opt_btn.has_focus()
#endregion
#region 生命周期与引擎回调

func _ready():
	opt_btn.item_selected.connect(
		func(index:int):
			ui_val_changed.emit(index)
	)
	
	# wtf, transparent background is a mess
	var popup := opt_btn.get_popup()
	popup.transparent_bg = true
	popup.transparent = true
#endregion
#region 公共接口

func setup(params := []):
	opt_btn.clear()
	for p in params:
		opt_btn.add_item(p)
#endregion
