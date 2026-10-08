@abstract
extends Node2D
class_name CharacterAnimationAdapter
#region 独立表现接口
## 适配层没有生命、技能许可或死亡规则；只接收动作命令及战斗 delta。
signal action_started(action: StringName)
signal action_completed(action: StringName)
signal action_looped(action: StringName)
signal appearance_changed(skins: Array[StringName])
@export var profile: CharacterAnimationProfile
var last_error: String = ""
#endregion
#region 公共接口
@abstract func play_action(action: StringName, restart: bool = false) -> bool
@abstract func set_facing(direction: int) -> void
@abstract func get_facing() -> int
@abstract func set_skin(skin_name: StringName) -> bool
@abstract func set_skins(skin_names: Array[StringName]) -> bool
@abstract func set_equipment_skin(part: StringName, skin_name: StringName) -> bool
@abstract func get_skin_names() -> Array[StringName]
@abstract func advance_animation(delta: float) -> void
@abstract func get_current_action() -> StringName
@abstract func get_action_duration(action: StringName) -> float
@abstract func get_playback_time() -> float
@abstract func get_playback_progress() -> float
@abstract func get_socket_global_transform(socket: StringName) -> Transform2D
@abstract func is_socket_active(socket: StringName) -> bool

## 状态表现与动作播放分别推进，每实体每个战斗tick只调用一次。
func advance_status_visuals(_delta: float) -> void:
	pass

func clear_status_visuals() -> void:
	pass
#endregion
