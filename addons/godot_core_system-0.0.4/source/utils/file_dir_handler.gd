extends Node
class_name FileDirHandler
#region 公共接口

static func get_object_script_dir(object:Object)->String:
	return object.get_script().resource_path.get_base_dir()
#endregion
