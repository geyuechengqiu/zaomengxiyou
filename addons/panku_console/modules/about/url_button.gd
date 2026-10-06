extends Button
#region 配置与运行状态

@export var url:String
#endregion
#region 生命周期与引擎回调

func _ready():
	pressed.connect(
		func():
			OS.shell_open(url)
	)
#endregion
