extends ModuleOptions
#region 配置与运行状态

@export_group("keyboard_shortcuts")

@export var export_button_open_keyboard_shortcuts := "Open Keyboard Shortcuts"
#endregion
#region 公共接口

func open_keyboard_shortcuts():
	_module.open_window()
#endregion
