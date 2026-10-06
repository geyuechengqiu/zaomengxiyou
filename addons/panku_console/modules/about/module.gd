class_name PankuModuleAbout extends PankuModule
#region 配置与运行状态

var window:PankuLynxWindow
#endregion
#region 类型与常量
const ui = preload("./about.tscn")
#endregion
#region 公共接口

func open_window():
	if window: return
	var ui_instance = ui.instantiate()
	ui_instance._module = self
	window = core.windows_manager.create_window(ui_instance)
	window.set_window_title_text("About")
	window.show_window()
	window.window_closed.connect(
		func(): window = null
	)
#endregion
