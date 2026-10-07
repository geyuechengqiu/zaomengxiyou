extends Resource
class_name CharacterAnimationProfile
#region 只读动画映射
@export var skeleton_data: Resource
@export var source_fps: float = 30.0
## 动作名称由战斗层使用，Spine 原动作名只在本映射中出现。
@export var animations: Dictionary[StringName, StringName] = {}
@export var looping_actions: Array[StringName] = []
@export var base_skin: StringName = &"基础"
@export var display_scale: float = 2.0
## 固定脚底校准，不按每帧或每个皮肤重新计算包围盒。
@export var skeleton_offset: Vector2 = Vector2.ZERO
@export var socket_bones: Dictionary[StringName, StringName] = {}
@export var socket_slots: Dictionary[StringName, StringName] = {}
@export var socket_offsets: Dictionary[StringName, Vector2] = {}
#endregion
#region 资源共享约定
func _validate_property(property: Dictionary) -> void:
	if property.name == "skeleton_data":
		property.usage |= PROPERTY_USAGE_NEVER_DUPLICATE
#endregion
