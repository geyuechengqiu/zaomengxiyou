extends "./row_ui.gd"
#region 配置与运行状态

@export var ledit:LineEdit
#endregion
#region 公共接口

func update_ui(val):
	ledit.text = str(val)
#endregion
