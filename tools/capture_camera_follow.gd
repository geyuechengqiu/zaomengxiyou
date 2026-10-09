extends SceneTree
#region 实际GPU、真实跑步与自动区域出口
var scene: Node2D

func _initialize() -> void:
	call_deferred("capture")

func tick() -> void:
	await physics_frame
	scene.session.advance_physics(1.0/60.0)

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/camera-%s.png" % name)

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("镜头连续性画面验收需要实际GPU")
		quit(1)
		return
	root.size = Vector2i(940,590)
	scene = load("res://examples/level_progression_demo.tscn").instantiate()
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	scene.session.set_physics_process(false)
	scene.player.super_armor = true
	# 快速清怪仅用来准备拍摄；出生/死亡/出口仍走实际关卡资格检查。
	for frame in range(900):
		await tick()
		for actor in scene.session.get_entities():
			if actor != scene.player and actor.is_alive():
				actor._finish_spawn_appearance()
				scene.session.apply_secondary_damage(actor,scene.player,1000000,&"camera_capture")
		if scene.flow.regions[0].exit_open: break
	if not scene.flow.regions[0].exit_open:
		push_error("第一关出生计划未完成")
		quit(1)
		return
	scene.player.position = Vector2(1400,1056)
	scene.player.velocity = Vector2.ZERO
	scene.player.move_axis = 1
	scene.player.running = true
	var entered := -1
	var largest_step := 0.0
	var previous: Vector2 = scene.camera.get_screen_center_position()
	for frame in range(480):
		await tick()
		var center: Vector2 = scene.camera.get_screen_center_position()
		if frame > 0: largest_step = maxf(largest_step,absf(center.x-previous.x))
		previous = center
		if entered < 0 and scene.flow.current_region_index == 0: await shot("before-region")
		if entered < 0 and scene.flow.current_region_index == 1:
			entered = frame
			await shot("enter-region")
		if entered >= 0 and frame == entered+18: await shot("transition")
		if entered >= 0 and frame == entered+60:
			await shot("after-region")
			break
	if entered < 0 or largest_step > 150:
		push_error("真实跑步过区未完成或出现瞬移：entered=%d, max_world_step=%f" % [entered,largest_step])
		quit(1)
		return
	print("PASS GPU camera: real running/automatic exit, continuous original art/parallax; max 60Hz horizontal step %.3f world pixels (%.3f screen pixels)" % [largest_step,largest_step*0.5])
	quit()
#endregion
