extends ModuleOptions
#region 配置与运行状态

@export_group("check_latest_release")

@export var export_button_check_update := "Check Update"
#endregion
#region 公共接口

func check_update():
	_module.check()
#endregion
