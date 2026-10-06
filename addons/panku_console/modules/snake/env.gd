#region 配置与运行状态
var _module:PankuModule
#endregion
#region 类型与常量

const _HELP_execute = "Play Snake Game"
#endregion
#region 公共接口
func play() -> void:
	_module.add_snake_window()

func leader_board() -> String:
	var content = ""
	content += "== Learder Board ==\n"
	content += str(_module.leader_board_arr)
	return content
#endregion
