extends CharacterAnimationAdapter
class_name SpineAnimationAdapter
#region Spine 私有播放状态
@export var sprite_path: NodePath = ^"SpineVisual"
@export var animation_player_path: NodePath = ^"AnimationPlayer"
@export var spine_player_path: NodePath = ^"SpineVisual/SpineAnimationTrack/SpineVisual Track 0"
var _sprite: SpineSprite
var _player: AnimationPlayer
var _spine_player: AnimationPlayer
var _action: StringName = &""
var _facing: int = 1
var _entry: SpineTrackEntry
var _skins: Array[StringName] = []
var _composite_skin: SpineSkin
var _completed: bool = false
var _initialized: bool = false
var _track_time: float = 0.0
#endregion
#region 生命周期
func _ready() -> void:
	initialize_adapter()

func initialize_adapter() -> bool:
	if _initialized:
		return true
	if profile == null or not profile.skeleton_data is SpineSkeletonDataResource:
		return _fail("动画适配层需要 SpineSkeletonDataResource 和动作映射")
	var data := profile.skeleton_data as SpineSkeletonDataResource
	if not data.is_skeleton_data_loaded():
		return _fail("Spine 数据未加载，请检查 atlas/skel 路径与引擎运行时")
	if not is_equal_approx(data.get_fps(), profile.source_fps):
		return _fail("动作配置与 Spine 原素材帧率不一致")
	if not is_finite(profile.display_scale) or profile.display_scale <= 0.0:
		return _fail("显示比例必须是有限正数，镜像通过 set_facing 实现")
	for action in profile.animations:
		if data.find_animation(String(profile.animations[action])) == null:
			return _fail("Spine 缺少映射动作：" + String(action))
	for socket in profile.socket_bones:
		if data.find_bone(String(profile.socket_bones[socket])) == null:
			return _fail("Spine 缺少挂点骨骼：" + String(socket))
	_sprite = get_node_or_null(sprite_path) as SpineSprite
	_player = get_node_or_null(animation_player_path) as AnimationPlayer
	_spine_player = get_node_or_null(spine_player_path) as AnimationPlayer
	if _sprite == null or _player == null or _spine_player == null:
		return _fail("请在角色表现场景预置 SpineSprite、SpineAnimationTrack 和两个 AnimationPlayer")
	if _sprite.get_skeleton_data_res() != data:
		return _fail("场景 SpineSprite 与动画配置的骨架资源不一致")
	for action in profile.animations:
		if not _player.has_animation(action):
			return _fail("AnimationPlayer 缺少语义动作：" + String(action))
		# 编辑器允许用多个 Spine clip 编排语义动作；动作时长以主时间轴为准。
		if _player.get_animation(action).length <= 0.0:
			return _fail("AnimationPlayer 动作时长必须大于零：" + String(action))
		if not _has_native_binding(action):
			return _fail("AnimationPlayer 的原生动画轨道或循环配置不正确：" + String(action))
	# 编辑器保留自动预览；游戏中两个播放器与 Spine 均只由战斗时钟驱动。
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_spine_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_sprite.set_update_mode(SpineConstant.UpdateMode_Manual)
	_player.animation_finished.connect(_on_animation_finished)
	_initialized = true
	if not set_skins([]):
		return false
	set_facing(_facing)
	return true

func _has_native_binding(action: StringName) -> bool:
	var looping := profile.looping_actions.has(action)
	var clip := _player.get_animation(action)
	var native := String(profile.animations[action]) + ("_looped" if looping else "")
	if not _spine_player.has_animation(native) or (clip.loop_mode != Animation.LOOP_NONE) != looping:
		return false
	var root_node := _player.get_node(_player.root_node)
	for index in range(clip.get_track_count()):
		if clip.track_get_type(index) == Animation.TYPE_ANIMATION and root_node.get_node_or_null(clip.track_get_path(index)) == _spine_player:
			if clip.track_get_key_count(index) > 0 and is_zero_approx(clip.track_get_key_time(index, 0)) and String(clip.track_get_key_value(index, 0)) == native:
				for key in range(clip.track_get_key_count(index)):
					if not _spine_player.has_animation(clip.track_get_key_value(index, key)):
						return false
				return true
	return false
#endregion
#region 动作与时间
func play_action(action: StringName, restart: bool = false) -> bool:
	if not _initialized:
		# 保留初始化的首个错误，以便未来资源配置问题可以直接诊断。
		return false
	if not profile.animations.has(action):
		return _fail("动作未映射或适配层尚未初始化：" + String(action))
	if action == _action and not restart:
		return true
	_action = action
	_completed = false
	_track_time = 0.0
	_player.stop()
	_player.play(action)
	_player.advance(0.0)
	_apply_player_pose()
	action_started.emit(action)
	return true

func advance_animation(delta: float) -> void:
	if _initialized and is_finite(delta) and delta > 0.0:
		var duration := get_action_duration(_action)
		var previous := get_playback_time()
		var looping := profile.looping_actions.has(_action)
		if _player.is_playing():
			_track_time += delta * _player.speed_scale
			_player.advance(delta)
			_apply_player_pose()
			if looping and duration > 0.0:
				for loop_index in range(int(floor((previous + delta * _player.speed_scale) / duration))):
					action_looped.emit(_action)

func _apply_player_pose() -> void:
	# 手动模式的动画轨道只选择子 clip，不自动推进子播放器。
	# 从主时间轴读取当前 key 与局部时间，保留编辑器编排的多个 clip。
	var master := _player.get_animation(_action)
	var time := get_playback_time()
	for track in range(master.get_track_count()):
		if master.track_get_type(track) != Animation.TYPE_ANIMATION or _player.get_node(_player.root_node).get_node_or_null(master.track_get_path(track)) != _spine_player:
			continue
		for key in range(master.track_get_key_count(track) - 1, -1, -1):
			var start := master.track_get_key_time(track, key)
			if start > time:
				continue
			var clip_name := StringName(master.track_get_key_value(track, key))
			if not _spine_player.has_animation(clip_name):
				continue
			var clip := _spine_player.get_animation(clip_name)
			var local_time := maxf(0.0, time - start)
			local_time = fmod(local_time, clip.length) if clip.loop_mode != Animation.LOOP_NONE else minf(local_time, clip.length)
			if _spine_player.current_animation != clip_name:
				_spine_player.play(clip_name)
			_spine_player.seek(local_time, true)
			_spine_player.advance(0.0)
			# 原生 SpineAnimationTrack 在骨架更新时提交 animation_name 的变化。
			_sprite.update_skeleton(0.0)
			_entry = _sprite.get_animation_state().get_track(0)
			if _entry != null:
				_entry.set_track_time(local_time)
			break
	_entry = _sprite.get_animation_state().get_track(0)
	if _entry != null:
		_sprite.update_skeleton(0.0)

func get_animation_player() -> AnimationPlayer:
	return _player

func get_current_action() -> StringName:
	return _action

func get_action_duration(action: StringName) -> float:
	if not _initialized or not profile.animations.has(action):
		return 0.0
	return _player.get_animation(action).length

func get_playback_time() -> float:
	return _player.current_animation_position if _initialized and not _action.is_empty() else 0.0

func get_playback_progress() -> float:
	var duration := get_action_duration(_action)
	return clampf(get_playback_time() / duration, 0.0, 1.0) if duration > 0.0 else 0.0

func get_track_time() -> float:
	return _track_time
#endregion
#region 朝向与皮肤
func set_facing(direction: int) -> void:
	if direction == 0:
		return
	_facing = 1 if direction > 0 else -1
	if _initialized:
		_sprite.get_skeleton().set_scale_x(float(_facing))
		_sprite.update_skeleton(0.0)

func get_facing() -> int:
	return _facing

func set_skin(skin_name: StringName) -> bool:
	if not _initialized:
		return _fail("适配层尚未初始化")
	var selected: Array[StringName] = []
	if skin_name != profile.base_skin:
		selected.append(skin_name)
	return set_skins(selected)

func set_skins(skin_names: Array[StringName]) -> bool:
	if not _initialized:
		return _fail("适配层尚未初始化")
	var data := _sprite.get_skeleton_data_res()
	var selected: Array[StringName] = [profile.base_skin]
	for id in skin_names:
		if not selected.has(id):
			selected.append(id)
	for id in selected:
		if data.find_skin(String(id)) == null:
			return _fail("皮肤不存在：" + String(id))
	var custom := _sprite.new_skin("character-appearance")
	for id in selected:
		custom.add_skin(data.find_skin(String(id)))
	_composite_skin = custom
	_sprite.get_skeleton().set_skin(custom)
	_sprite.get_skeleton().set_slots_to_setup_pose()
	## 重新应用当前时刻的附件与 drawOrder；不 set_animation、不改变 TrackEntry 时间。
	_sprite.update_skeleton(0.0)
	_skins = selected
	appearance_changed.emit(get_skin_names())
	return true

func set_equipment_skin(part: StringName, skin_name: StringName) -> bool:
	var prefixes := {&"armor": "衣服/", &"helmet": "头盔/", &"weapon": "武器/", &"outfit": "套装/"}
	if not prefixes.has(part):
		return _fail("未知外观装备位置：" + String(part))
	var prefix: String = prefixes[part]
	if not skin_name.is_empty() and not String(skin_name).begins_with(prefix):
		return _fail("皮肤与外观装备位置不匹配")
	var next: Array[StringName] = []
	for id in _skins:
		if id != profile.base_skin and not String(id).begins_with(prefix):
			next.append(id)
	if not skin_name.is_empty():
		next.append(skin_name)
	return set_skins(next)

func get_skin_names() -> Array[StringName]:
	return _skins.duplicate()

func get_available_skins() -> Array[StringName]:
	var result: Array[StringName] = []
	if _initialized:
		for skin in _sprite.get_skeleton_data_res().get_skins():
			result.append(StringName(skin.get_name()))
	return result
#endregion
#region 挂点与层序查询
func get_socket_global_transform(socket: StringName) -> Transform2D:
	if not _initialized or not profile.socket_bones.has(socket):
		last_error = "挂点不存在：" + String(socket)
		return global_transform
	var bone: StringName = profile.socket_bones[socket]
	var transform := _sprite.get_global_bone_transform(String(bone))
	return transform.translated_local(profile.socket_offsets.get(socket, Vector2.ZERO))

func get_draw_order() -> Array[StringName]:
	var result: Array[StringName] = []
	if _initialized:
		for slot in _sprite.get_skeleton().get_draw_order():
			result.append(StringName(slot.get_data().get_name()))
	return result

func is_socket_active(socket: StringName) -> bool:
	if not _initialized or not profile.socket_bones.has(socket):
		return false
	if not profile.socket_slots.has(socket):
		return true
	return not get_slot_attachment_name(profile.socket_slots[socket]).is_empty()

func get_slot_attachment_name(slot_name: StringName) -> String:
	if not _initialized:
		return ""
	var slot := _sprite.get_skeleton().find_slot(String(slot_name))
	if slot == null or slot.get_pose().get_attachment() == null:
		return ""
	return slot.get_pose().get_attachment().get_attachment_name()

func get_visual_bounds_global() -> Rect2:
	if not _initialized:
		return Rect2()
	return _sprite.global_transform * _sprite.get_skeleton().get_bounds()
#endregion
#region AnimationPlayer 通知
func _on_animation_finished(action: StringName) -> void:
	if action != _action:
		return
	if not _completed:
		_completed = true
		action_completed.emit(_action)

func _fail(message: String) -> bool:
	last_error = message
	return false
#endregion
