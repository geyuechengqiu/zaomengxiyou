@tool
extends Resource
class_name BattleDamageNumberLibrary
#region 原版数字贴图库
## 只读贴图定义；同名暴击别名保留为资源，显示时使用第一个标识。
@export var groups: Dictionary[String, Array] = {}

func get_group(id: String) -> Array:
	return groups.get(id, [])
#endregion
