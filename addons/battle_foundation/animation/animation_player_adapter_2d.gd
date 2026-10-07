extends CharacterAnimationAdapter
class_name AnimationPlayerAdapter2D
#region 预置 AnimationPlayer 的通用 2D 后端
@export var player_path: NodePath = ^"AnimationPlayer"
@export var visual_path: NodePath = ^"Visual"
@export var skin_textures: Dictionary[StringName, Texture2D] = {}
var _player: AnimationPlayer
var _visual: Node2D
var _action: StringName
var _facing: int = 1
var _skins: Array[StringName] = []

func _ready() -> void:
	_player = get_node(player_path) as AnimationPlayer
	_visual = get_node(visual_path) as Node2D
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_player.animation_finished.connect(func(action): action_completed.emit(action))

func play_action(action: StringName, restart: bool = false) -> bool:
	if _player == null or not _player.has_animation(action):
		return false
	if action == _action and not restart:
		return true
	_action = action
	_player.play(action)
	_player.advance(0.0)
	action_started.emit(action)
	return true

func advance_animation(delta: float) -> void:
	if _player != null and delta > 0.0:
		_player.advance(delta)

func set_facing(direction: int) -> void:
	if direction != 0:
		_facing = 1 if direction > 0 else -1
		if _visual != null:
			_visual.scale.x = absf(_visual.scale.x) * _facing

func get_facing() -> int:
	return _facing

func set_skin(id: StringName) -> bool:
	if not skin_textures.has(id) or not _visual is Sprite2D:
		return false
	(_visual as Sprite2D).texture = skin_textures[id]
	_skins = [id]
	appearance_changed.emit(_skins.duplicate())
	return true

func set_skins(ids: Array[StringName]) -> bool:
	return ids.is_empty() or (ids.size() == 1 and set_skin(ids[0]))

func set_equipment_skin(_part: StringName, id: StringName) -> bool:
	return set_skin(id)

func get_skin_names() -> Array[StringName]:
	return _skins.duplicate()

func get_current_action() -> StringName:
	return _action

func get_action_duration(action: StringName) -> float:
	return _player.get_animation(action).length if _player != null and _player.has_animation(action) else 0.0

func get_playback_time() -> float:
	return _player.current_animation_position if _player != null and not _action.is_empty() else 0.0

func get_playback_progress() -> float:
	var duration := get_action_duration(_action)
	return clampf(get_playback_time() / duration, 0.0, 1.0) if duration > 0.0 else 0.0

func get_socket_global_transform(_socket: StringName) -> Transform2D:
	return global_transform

func is_socket_active(_socket: StringName) -> bool:
	return false
#endregion
