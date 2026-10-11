extends SceneTree
#region 编辑器可视化时间轴验收
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	if not Engine.is_editor_hint():
		push_error("Use --editor --script tools/verify_editor_wukong_attack_effects.gd")
		quit(1)
		return
	call_deferred("_verify")

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _verify() -> void:
	await create_timer(1.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	EditorInterface.open_scene_from_path("res://data/characters/sunwukong/animation/sunwukong_visual.tscn")
	for tick in range(5):
		await process_frame
	var visual := EditorInterface.get_edited_scene_root()
	var player := visual.get_node("AnimationPlayer") as AnimationPlayer
	EditorInterface.edit_node(player)
	for tick in range(5):
		await process_frame
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var starts: Array[int] = [4, 4, 2, 0, 6, 3, 5]
	var actions: Array[StringName] = [&"attack_1", &"attack_2", &"attack_3", &"attack_4", &"attack_5", &"run_attack", &"jump_attack"]
	var natives: Array[String] = ["attack1", "attack2", "attack3", "attack4", "attack5", "runAttack", "jumpAttack"]
	var armatures: Array[int] = [0, 1, 2, 3, 4, 6, 5]
	var durations: Array[int] = [8, 7, 10, 8, 9, 9, 7]
	for index in range(actions.size()):
		var action := actions[index]
		player.play(action)
		var end := minf(player.get_animation(action).length, (starts[index] + durations[index]) / 30.0)
		var times: Array[float] = [0.001, starts[index] / 30.0 + 0.05, end - 0.01, 0.001]
		if index == 3:
			times.append_array([0.35, 0.54, 0.1])
		for time in times:
			player.seek(time, true, true)
			await process_frame
			await process_frame
			for slot in range(2):
				var sprite := visual.get_node("AttackEffects/" + ("Primary" if slot == 0 else "Secondary")) as SpineSprite
				var start := starts[index] / 30.0 if slot == 0 else 8.0 / 30.0
				var finish := end if slot == 0 else 16.0 / 30.0
				var expected := (slot == 0 or index == 3) and time >= start and time < finish
				_check(sprite.visible == expected, "编辑器前后拖动 %s / %d @ %.4f 的可见性" % [action, slot, time])
				var attachment_slots: Array[String] = []
				for bone_slot in sprite.get_skeleton().get_slots():
					if bone_slot.get_pose().get_attachment() != null:
						attachment_slots.append(bone_slot.get_data().get_name())
				var prefix := "attackV427__armature_%d__" % armatures[index]
				_check(attachment_slots.all(func(name: String) -> bool: return name.begins_with(prefix)) if expected else attachment_slots.is_empty(), "编辑器只保留当前攻击附件；前后 seek 和切段无残留")
				if expected:
					var entry := sprite.get_animation_state().get_track(0)
					_check(entry != null and entry.get_animation().get_name() == natives[index], "编辑器选择正确特效素材")
					_check(entry != null and absf(entry.get_track_time() - time + start) < 0.001, "编辑器局部时间精确同步 Spine：%s / %d @ %.4f；实际%.4f，预期%.4f" % [action, slot, time, entry.get_track_time() if entry != null else -1.0, time - start])
	for action in [&"idle", &"jump_2", &"hurt", &"death"]:
		player.play(&"attack_4")
		player.seek(0.35, true, true)
		await process_frame
		player.play(action)
		player.seek(0.0, true, true)
		await process_frame
		_check(not visual.get_node("AttackEffects/Primary").visible and not visual.get_node("AttackEffects/Secondary").visible, "编辑器切换非攻击动作清理特效")
	if failures.is_empty():
		print("PASS editor wukong attack effects: %d checks; authored nodes, forwards/backwards scrubbing, eight source windows and action switching" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
#endregion
