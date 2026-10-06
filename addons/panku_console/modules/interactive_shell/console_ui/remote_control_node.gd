extends Control
#region 配置与运行状态

@export
var target_control:Control
#endregion
#region 生命周期与引擎回调

func _ready():
	if not target_control:
		return
		
	target_control.resized.connect(
		func():
			custom_minimum_size = target_control.get_minimum_size()
	)
	
	target_control.resized.emit()
#endregion
