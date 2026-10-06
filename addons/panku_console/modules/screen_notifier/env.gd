#region 配置与运行状态
var _module:PankuModule
#endregion
#region 类型与常量

const _HELP_notify = "Generate a notification"
#endregion
#region 公共接口
func notify(any):
	_module.notify(str(any))
#endregion
