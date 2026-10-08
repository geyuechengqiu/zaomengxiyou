@tool
extends RefCounted
class_name SpineTimelinePose
#region 从已保存的主动画轨道精确求原生姿态
static func apply(sprite: SpineSprite, nested: AnimationPlayer, master: Animation, root: Node, time: float, reset_pose: bool = false) -> bool:
	# 合并特效中的各动画只键控自己的槽位，clear_track 不恢复骨架附件。
	# 每次重新采样都从初始姿态开始，避免连击和向后 seek 继承旧附件/变形。
	if reset_pose:
		sprite.get_skeleton().set_to_setup_pose()
	var bound := false
	var posed_time: float = 0.0
	for track in range(master.get_track_count()):
		if not master.track_is_enabled(track) or master.track_get_type(track) != Animation.TYPE_ANIMATION or root.get_node_or_null(master.track_get_path(track)) != nested:
			continue
		for key in range(master.track_get_key_count(track) - 1, -1, -1):
			var start := master.track_get_key_time(track, key)
			# key 为 float32，clip.length/position 为 double，末帧也要清理。
			if start - time > 0.0000001:
				continue
			var name := StringName(master.track_get_key_value(track, key))
			if not nested.has_animation(name):
				continue
			bound = true
			var clip := nested.get_animation(name)
			var local_time := maxf(0.0, time - start)
			local_time = fmod(local_time, clip.length) if is_looping(clip, local_time) else minf(local_time, clip.length)
			posed_time = local_time
			if nested.current_animation != name:
				nested.play(name)
			nested.seek(local_time, true)
			nested.advance(0.0)
			# 原生 SpineAnimationTrack 在骨架更新时提交 animation_name 变化。
			sprite.update_skeleton(0.0)
			var entry := sprite.get_animation_state().get_track(0)
			if name == &"RESET":
				sprite.get_animation_state().clear_track(0)
			elif entry != null:
				entry.set_track_time(local_time)
			break
	if sprite.get_animation_state().get_track(0) != null:
		if Engine.is_editor_hint():
			# 原生编辑器以 Animation.step 容差选择 key，可能提前选择未来 RESET。
			# 在原生采样之后、骨架应用之前提交精确局部时间，保持姿态与进度一致。
			var sample_pose := func(updated_sprite: SpineSprite) -> void:
				var sampled := updated_sprite.get_animation_state().get_track(0)
				if sampled != null:
					sampled.set_track_time(posed_time)
			sprite.before_animation_state_apply.connect(sample_pose)
			sprite.update_skeleton(0.0)
			sprite.before_animation_state_apply.disconnect(sample_pose)
		else:
			sprite.update_skeleton(0.0)
	return bound

static func is_looping(clip: Animation, time: float = 0.0) -> bool:
	if clip.loop_mode != Animation.LOOP_NONE:
		return true
	# Spine辅助播放器在编辑器重建后只保存原生loop属性轨道。
	# 手动采样同样读取该轨道，不能因为Animation.loop_mode缺失而停在终帧。
	for track in range(clip.get_track_count()):
		var path := clip.track_get_path(track)
		if clip.track_is_enabled(track) and clip.track_get_type(track) == Animation.TYPE_VALUE and path.get_subname_count() > 0 and path.get_subname(path.get_subname_count()-1) == &"loop":
			for key in range(clip.track_get_key_count(track)-1,-1,-1):
				if clip.track_get_key_time(track,key) <= time + 0.0000001:
					return bool(clip.track_get_key_value(track,key))
	return false
#endregion
