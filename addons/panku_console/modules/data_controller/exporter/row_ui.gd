extends HBoxContainer
#region 配置与运行状态

var name_label:Label:
	get: return get_node("VName")
#endregion
#region 信号

signal ui_val_changed(val)
#endregion
#region 公共接口

func get_ui_val():
	return null

func update_ui(val):
	pass

#stop sync if is active(eg. a line edit node is in focus)
func is_active() -> bool:
	return false
#endregion
