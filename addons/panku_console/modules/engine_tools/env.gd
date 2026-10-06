#region 配置与运行状态
var _module:PankuModule
#endregion
#region 类型与常量

const _HELP_toggle_fullscreen = "Toggle [fullscreen / windowed] mode"
#endregion
#region 公共接口
func toggle_fullscreen() -> void:
	_module.toggle_fullscreen()
#endregion
#region 类型与常量

const _HELP_set_time_scale = "Equals to [color=green]Engine.time_scale[/color]"
#endregion
#region 公共接口
func set_time_scale(val:float) -> void:
	_module.set_time_scale(val)
#endregion
#region 类型与常量

const _HELP_get_performance_info = "Show performance info"
#endregion
#region 公共接口
func get_performance_info() -> String:
	return _module.get_performance_info()
#endregion
#region 类型与常量

const _HELP_take_screenshot = "Take a screenshot of current window"
#endregion
#region 公共接口
func take_screenshot() -> void:
	_module.take_screenshot()
#endregion
#region 类型与常量

const _HELP_quit = "Quit application"
#endregion
#region 公共接口
func quit() -> void:
	_module.quit()
#endregion
#region 类型与常量

const _HELP_toggle_2d_collision_shape_visibility = "Toggle visibility of 2D collision shapes, useful for debugging"
#endregion
#region 公共接口
func toggle_2d_collision_shape_visibility() -> void:
	_module.toggle_2d_collision_shape_visibility()
#endregion
#region 类型与常量

const _HELP_reload_current_scene = "Reload current scene"
#endregion
#region 公共接口
func reload_current_scene() -> void:
	_module.reload_current_scene()

#endregion
