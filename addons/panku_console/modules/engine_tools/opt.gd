extends ModuleOptions
#region 配置与运行状态

@export_group("engine_tools")

@export var export_button_toggle_fullscreen := "Toggle Fullscreen"
#endregion
#region 公共接口

func toggle_fullscreen():
	_module.toggle_fullscreen()
#endregion
#region 配置与运行状态

@export var export_button_take_screenshot := "Take Screenshot"
#endregion
#region 公共接口

func take_screenshot():
	_module.take_screenshot()
#endregion
#region 配置与运行状态

@export var export_button_quit := "Quit"
#endregion
#region 公共接口

func quit():
	_module.quit()
#endregion
#region 配置与运行状态

@export var export_button_toggle_2d_debug_draw := "Toggle 2D Debug Draw"
#endregion
#region 公共接口

func toggle_2d_debug_draw():
	_module.toggle_2d_collision_shape_visibility()
#endregion
#region 配置与运行状态

@export var export_button_reload_current_scene := "Reload Current Scene"
#endregion
#region 公共接口

func reload_current_scene():
	_module.reload_current_scene()
#endregion
#region 配置与运行状态

@export_range(0.1, 2.0) var time_scale := 1.0:
	set(v):
		time_scale = v
		_module.set_time_scale(time_scale)

@export var readonly_performance_info:String:
	get:
		return _module.get_performance_info()
#endregion
