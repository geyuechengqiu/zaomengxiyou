extends Node
class_name CoreOperationManager

#region 类型与常量
## 可选操作模块：创建/查询独立控制器，不全局监听输入、不持有角色强引用。
const Controller = preload("./operation_controller.gd")
const Profile = preload("./operation_profile.gd")
const Intent = preload("./operation_intent.gd")
#endregion
#region 配置与运行状态
var _controllers: Dictionary = {}
#endregion


#region 公共接口
func create_controller(id: StringName, profile: Profile = null, device_filter: int = -1) -> Controller:
	if id.is_empty() or get_controller(id) != null:
		push_error("Operation controller %s already registered" % id)
		return null
	var controller := Controller.new()
	controller.name = "OperationController"
	controller.profile = profile
	controller.device_filter = device_filter
	register_controller(id, controller)
	# 调用方负责 add_child，确保控制器继承角色子树的暂停/禁用行为。
	return controller


func register_controller(id: StringName, controller: Controller) -> bool:
	# 继承 Controller 的触屏/AI/网络适配器也可注册，不必修改工厂或核心状态机。
	if id.is_empty() or not is_instance_valid(controller) or get_controller(id) != null or not controller.controller_id.is_empty():
		return false
	controller.controller_id = id
	_controllers[id] = weakref(controller)
	controller.tree_exited.connect(_unregister_controller.bind(id, controller.get_instance_id()))
	return true


func get_controller(id: StringName) -> Controller:
	var reference: WeakRef = _controllers.get(id)
	if reference == null:
		return null
	var controller = reference.get_ref()
	if controller == null:
		_controllers.erase(id)
	return controller as Controller
#endregion


#region 内部实现
func _unregister_controller(id: StringName, instance_id: int) -> void:
	var controller := get_controller(id)
	if controller != null and controller.get_instance_id() == instance_id:
		_controllers.erase(id)
#endregion
