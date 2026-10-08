extends SpineSprite
class_name BattleSpinePoseMirror2D
#region 预置Spine快照：共用图集、独占姿态，不推进角色动画
var _source: SpineSprite
var _bones: Array = []
var _slots: Array = []
var _skin_names: Array[StringName] = []
var _skin: SpineSkin
var capture_count: int = 0

func _ready() -> void:
	set_update_mode(SpineConstant.UpdateMode_Manual)
	world_transforms_changed.connect(_copy_resolved_pose)

func capture(source: SpineSprite, origin: Vector2, unit_scale: float, skin_names: Array[StringName]) -> void:
	if _source != source:
		_source = source
		_bones.clear()
		_slots.clear()
		assert(get_skeleton_data_res() == source.get_skeleton_data_res(), "预置快照与角色必须使用同一Spine数据")
		var from_bones := source.get_skeleton().get_bones()
		var to_bones := get_skeleton().get_bones()
		for index in range(from_bones.size()): _bones.append([from_bones[index], to_bones[index]])
		var from_slots := source.get_skeleton().get_slots()
		var to_slots := get_skeleton().get_slots()
		for index in range(from_slots.size()): _slots.append([from_slots[index], to_slots[index]])
	var skeleton := get_skeleton()
	# runtime复合Skin由各SpineSprite持有，不能将源角色的复合Skin交给快照拥有。
	# 换装后旧残影仍持有自己的Skin；仅只读图集附件来自共同的数据资源。
	if _skin == null or _skin_names != skin_names:
		var next := new_skin("wushuang_snapshot")
		for name in skin_names:
			next.add_skin(get_skeleton_data_res().find_skin(String(name)))
		skeleton.set_skin(next)
		_skin = next
		_skin_names = skin_names.duplicate()
	skeleton.set_color(source.get_skeleton().get_color())
	skeleton.set_scale_x(source.get_skeleton().get_scale_x())
	skeleton.set_scale_y(source.get_skeleton().get_scale_y())
	var entry := source.get_animation_state().get_track(0)
	if entry != null:
		var current := get_animation_state().get_track(0)
		var name := entry.get_animation().get_name()
		if current == null or current.get_animation().get_name() != name:
			current = get_animation_state().set_animation(name, entry.get_loop(), 0)
			current.set_mix_duration(0.0)
		current.set_track_time(entry.get_track_time())
	else:
		get_animation_state().clear_track(0)
	# 姿态采样保留原动画drawOrder；原生生成网格前覆写已解算骨骼与槽位。
	transform = Transform2D(source.transform.x / unit_scale, source.transform.y / unit_scale, origin + source.transform.origin / unit_scale)
	update_skeleton(0.0)
	capture_count += 1

func _copy_resolved_pose(_sprite: SpineSprite) -> void:
	if not is_instance_valid(_source): return
	for pair in _bones:
		var from: SpineBonePose = pair[0].get_pose()
		var to: SpineBonePose = pair[1].get_pose()
		to.set_x(from.get_x())
		to.set_y(from.get_y())
		to.set_rotation(from.get_rotation())
		to.set_scale_x(from.get_scale_x())
		to.set_scale_y(from.get_scale_y())
		to.set_shear_x(from.get_shear_x())
		to.set_shear_y(from.get_shear_y())
		to.set_a(from.get_a())
		to.set_b(from.get_b())
		to.set_c(from.get_c())
		to.set_d(from.get_d())
		to.set_world_x(from.get_world_x())
		to.set_world_y(from.get_world_y())
	for pair in _slots:
		var from: SpineSlotPose = pair[0].get_pose()
		var to: SpineSlotPose = pair[1].get_pose()
		to.set_attachment(from.get_attachment())
		to.set_color(from.get_color())
		to.set_dark_color(from.get_dark_color())
		to.set_deform(from.get_deform())
		to.set_sequence_index(from.get_sequence_index())
#endregion
