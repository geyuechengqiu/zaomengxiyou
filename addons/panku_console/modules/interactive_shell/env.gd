#region 配置与运行状态
var _module:PankuModule
#endregion
#region 公共接口

func open_window(): _module.open_window()

func open_launcher(): _module.open_launcher()

func set_unified_window_visibility(enabled:bool):
	_module.set_unified_window_visibility(enabled)

func set_pause_if_popup(enabled:bool):
	_module.set_pause_if_popup(enabled)
#endregion
