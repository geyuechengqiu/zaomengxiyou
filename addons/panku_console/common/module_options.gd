class_name ModuleOptions extends Resource
#region 配置与运行状态

var _module:PankuModule

var _loaded := false
#endregion
#region 公共接口

#FIXME: Tricky part of saving data, needs to be reworked
func update_setting(key: String, value: Variant):
	self.set(key, value)
	if _loaded and _module:
		_module.save_module_data(key, value)
#endregion
