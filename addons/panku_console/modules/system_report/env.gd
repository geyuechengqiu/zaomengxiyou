#region 配置与运行状态
var _os_report = preload("./os_report.gd").new()
var _module:PankuModule
#endregion
#region 类型与常量

const _HELP_execute = "Show detailed OS report"
#endregion
#region 公共接口
func execute() -> String:
	_module.core.notify("Please wait, this may take a while...")
	_os_report.inspect()
	var report =  "".join(_os_report.rtl)
	return report
#endregion
