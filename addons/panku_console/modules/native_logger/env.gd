#region 配置与运行状态
var _module:PankuModule
#endregion
#region 类型与常量

const _HELP_open = "Open logger window"
#endregion
#region 公共接口
func open() -> void:
	_module.open_window()
#endregion
#region 类型与常量

const _HELP_toggle_overlay = "Toggle visibility of logger overlay"
#endregion
#region 公共接口
func toggle_overlay() -> void:
	_module.toggle_overlay()
#endregion
#region 类型与常量

const _HELP_clear = "Clear logs"
#endregion
#region 公共接口
func clear() -> void:
	_module.logger_ui.clear_all()
#endregion
