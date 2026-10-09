@tool
extends PhantomCameraHost
class_name BattlePhantomCameraHost
#region 场景镜头作用域与严格关卡限界
## 同一个Manager可以服务多个会话，Host只接受当前预置镜头根下的PCam。
@export var phantom_root_path: NodePath

func _pcam_is_in_host_layer(pcam: Node) -> bool:
	var root := get_node_or_null(phantom_root_path)
	return is_instance_valid(root) and root.is_ancestor_of(pcam) and super._pcam_is_in_host_layer(pcam)

## 原插件限界通知为全局广播；读取自己的活动镜头避免跨会话污染。
## 过渡也保留显式边界，不接受原Host在Tween开始时广播的无限边界。
func _update_limit_2d(side: int, _limit: int) -> void:
	var active := get_active_pcam() as PhantomCamera2D
	if is_instance_valid(active) and is_instance_valid(camera_2d):
		camera_2d.set_limit(side, active.get_limit(side))
#endregion
