#region 配置与运行状态
var _module:PankuModule
#endregion
#region 类型与常量

const _HELP_toggle = "The good old days"
#endregion
#region 公共接口
func toggle() -> void:
    _module.toggle_crt_effect()
#endregion
