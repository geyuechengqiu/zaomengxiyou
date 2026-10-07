extends SceneTree
#region 真正编辑器模式下验证主时间轴预览
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	if not Engine.is_editor_hint():
		push_error("请使用 --editor --script tools/verify_editor_animation_authoring.gd")
		quit(1)
		return
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _verify() -> void:
	# GUI 编辑器初始化比 headless 慢；先等待编辑器窗口与文件系统就绪。
	await create_timer(1.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	EditorInterface.open_scene_from_path("res://data/animation/sunwukong_visual.tscn")
	for frame in range(5):
		await process_frame
	var visual := EditorInterface.get_edited_scene_root() as Node2D
	if visual == null:
		push_error("编辑器未能打开角色表现场景")
		quit(1)
		return
	var player := visual.get_node("AnimationPlayer") as AnimationPlayer
	var sprite := visual.get_node("SpineVisual") as SpineSprite
	var profile := visual.get("profile") as CharacterAnimationProfile
	# 自定义 MainLoop 先于 autoload 建立；不要提前编译依赖 GAS/Core 的类图。
	var box := visual.get_node("AttackHitbox") as Node2D
	var collision := box.get_node("CollisionShape2D") as CollisionShape2D
	var shape := collision.shape
	EditorInterface.edit_node(player)
	for frame in range(5):
		await process_frame
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for action in profile.animations:
		player.play(action)
		var times := [0.04, player.get_animation(action).length * 0.75]
		if action == &"attack_4":
			times.append_array([7.99 / profile.source_fps, 8.01 / profile.source_fps])
		times.append(0.01)
		for time in times:
			player.seek(time, true, true)
			await process_frame
			var entry := sprite.get_animation_state().get_track(0)
			_check(entry != null and entry.get_animation().get_name() == String(profile.animations[action]), "编辑器时间轴选择原生动作：" + String(action))
			_check(entry != null and absf(entry.get_track_time() - time) < 0.001, "前后拖动时间轴精确同步 Spine 姿态：" + String(action))
			var hit_index := 2 if action == &"attack_4" and time >= 8.0 / profile.source_fps else 1
			_check(collision.shape == shape and visual.get_children().filter(func(node): return node is Area2D).size() == 1, "时间轴始终复用一个节点及形状")
			_check(box.visible == String(action).begins_with("attack_"), "仅攻击动作显示单一判定框：" + String(action))
			if String(action).begins_with("attack_"):
				_check(box.get("action") == action and box.get("hit_index") == hit_index, "从技能帧数据选择当前命中序号")
				var payload: Dictionary = box.call("find_impact_payload", box.get("preview_abilities")[int(String(action).trim_prefix("attack_")) - 1], hit_index)
				var rect: Rect2 = payload.hit_rect
				rect.position += Vector2(payload.get("hit_offset", Vector2.ZERO))
				rect = Rect2(rect.position * 2.0, rect.size * 2.0)
				_check((box.call("get_rect_local", visual, 1) as Rect2).is_equal_approx(rect), "预览框矩形来自当前技能数据")
	# 修改技能素材帧，验证切换来自数据，不是动画轨道硬编码的 8/30 秒。
	var fourth: Resource = box.get("preview_abilities")[3]
	var marker: Resource = fourth.get("features")[1].get("events")[1]
	var original_frame: int = marker.get("source_frame")
	marker.set("source_frame", 10)
	player.play(&"attack_4")
	for time in [0.28, 0.34]:
		player.seek(time, true, true)
		await process_frame
		_check(box.get("hit_index") == (1 if time < 10.0 / profile.source_fps else 2), "修改技能命中帧自动改变统一框的预览切换时机")
	marker.set("source_frame", original_frame)
	if failures.is_empty():
		print("PASS editor animation authoring: %d checks; 14 native actions, timeline scrubbing and one shared skill-driven hitbox" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
#endregion
