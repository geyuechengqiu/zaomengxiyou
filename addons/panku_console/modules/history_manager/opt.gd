extends ModuleOptions
#region 配置与运行状态

@export_group("history_manager")

@export var export_button_open_window := "Open Window"
#endregion
#region 公共接口
func open_window():
	_module.open_window()
#endregion
