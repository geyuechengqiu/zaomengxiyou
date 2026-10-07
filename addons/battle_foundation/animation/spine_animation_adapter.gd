extends CharacterAnimationAdapter
class_name SpineAnimationAdapter
#region Spine 私有播放状态
var _sprite: SpineSprite
var _action: StringName = &""
var _facing: int = 1
var _entry: SpineTrackEntry
var _skins: Array[StringName] = []
var _composite_skin: SpineSkin
var _completed: bool = false
var _initialized: bool = false
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
	_sprite = SpineSprite.new()
	_sprite.name = "SpineVisual"
	_sprite.set_update_mode(SpineConstant.UpdateMode_Manual)
	_sprite.scale = Vector2.ONE * profile.display_scale
	_sprite.position = profile.skeleton_offset * profile.display_scale
	add_child(_sprite)
	_sprite.set_skeleton_data_res(data)
	_sprite.animation_completed.connect(_on_spine_completed)
	_initialized = true
	if not set_skins([]):
		return false
	set_facing(_facing)
	return true
#endregion
#region 动作与时间
func play_action(action: StringName, restart: bool = false) -> bool:
	if not _initialized or not profile.animations.has(action):
		return _fail("动作未映射或适配层尚未初始化：" + String(action))
	if action == _action and not restart:
		return true
	_action = action
	_completed = false
	## 零混合保留原版逐帧附件与层序切换，不修改共享 skeleton_data.default_mix。
	_entry = _sprite.get_animation_state().set_animation(String(profile.animations[action]), profile.looping_actions.has(action), 0)
	_entry.set_mix_duration(0.0)
	_sprite.update_skeleton(0.0)
	action_started.emit(action)
	return true

func advance_animation(delta: float) -> void:
	if _initialized and is_finite(delta) and delta > 0.0:
		_sprite.update_skeleton(delta)

func get_current_action() -> StringName:
	return _action

func get_action_duration(action: StringName) -> float:
	if not _initialized or not profile.animations.has(action):
		return 0.0
	return (_sprite.get_skeleton_data_res().find_animation(String(profile.animations[action])) as SpineAnimation).get_duration()

func get_playback_time() -> float:
	return _entry.get_animation_time() if _entry != null else 0.0

func get_playback_progress() -> float:
	var duration := get_action_duration(_action)
	return clampf(get_playback_time() / duration, 0.0, 1.0) if duration > 0.0 else 0.0

func get_track_time() -> float:
	return _entry.get_track_time() if _entry != null else 0.0
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
#region Spine 通知
func _on_spine_completed(_sender: SpineSprite, _state: SpineAnimationState, entry: SpineTrackEntry) -> void:
	if entry.get_track_index() != 0 or _action.is_empty():
		return
	if entry.get_animation().get_name() != String(profile.animations[_action]):
		return
	if profile.looping_actions.has(_action):
		action_looped.emit(_action)
	elif not _completed:
		_completed = true
		action_completed.emit(_action)

func _fail(message: String) -> bool:
	last_error = message
	return false
#endregion
