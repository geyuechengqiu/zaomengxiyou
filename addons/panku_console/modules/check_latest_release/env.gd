#region 配置与运行状态
var _module:PankuModule
#endregion
#region 类型与常量

const _HELP_check = "Fetch latest release information from Github"
#endregion
#region 公共接口
func check():
	_module.check()
#endregion
