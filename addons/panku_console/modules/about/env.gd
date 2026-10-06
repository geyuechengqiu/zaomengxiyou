#region 配置与运行状态
var _module:PankuModule
#endregion
#region 类型与常量

const _HELP_open = "Open about window"
#endregion
#region 公共接口
func open() -> void:
	_module.open_window()
#endregion
