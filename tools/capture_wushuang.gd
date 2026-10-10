extends SceneTree
#region 真实GPU验收：开关对比与双向快照
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("无双画面验收需要真实GPU渲染，不能使用--headless")
		quit(1)
		return
	root.size = Vector2i(940, 590)
	DirAccess.make_dir_recursive_absolute("res://.cleanup-backup")
	# SceneTree命令行脚本使用无类型局部变量，避免自动加载注册前解析业务类型。
	var scene = load("res://tests/fixtures/wukong_skills_demo.tscn").instantiate()
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	scene.session.set_physics_process(false)
	scene.get_node("HUD").hide()
	for tick in range(8):
		await physics_frame
		scene.session.advance_physics(1.0 / 60.0)
	var player = scene.player
	player.position.x = 400
	player.wushuang.add_rage(10000)
	if not player.try_activate_skill(&"sunwukong_wushuang"):
		push_error("无双技能激活失败")
		quit(1)
		return
	player.move_axis = 1
	player.running = true
	for tick in range(65):
		await physics_frame
		scene.session.advance_physics(1.0 / 60.0)
	await RenderingServer.frame_post_draw
	var effect = player.get_node("AnimationAdapter/WushuangEffect")
	var original = root.get_texture().get_image()
	original.save_png("res://.cleanup-backup/wushuang-running-right.png")
	# 冻结同一人物姿态，分别隐藏红光与残影，检测实际像素贡献。
	effect.halo.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var without_halo = root.get_texture().get_image()
	var halo_pixels := changed_pixels(original, without_halo)
	effect.halo.show()
	var ghosts: Array[CanvasItem] = []
	for child in effect.get_node("GhostPool").get_children():
		if child.visible:
			ghosts.append(child)
			child.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var without_ghosts = root.get_texture().get_image()
	var ghost_pixels := changed_pixels(original, without_ghosts)
	for ghost in ghosts: ghost.show()
	if halo_pixels < 100 or ghost_pixels < 100:
		push_error("无双未正确渲染：红光%d像素、残影%d像素" % [halo_pixels, ghost_pixels])
		quit(1)
		return
	player.move_axis = -1
	for tick in range(50):
		await physics_frame
		scene.session.advance_physics(1.0 / 60.0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/wushuang-running-left.png")
	player.move_axis = 0
	player.running = false
	player.attributes.get_vital(&"mana").set_current_value(100)
	player.try_activate_skill(&"sunwukong_skill8")
	for tick in range(30):
		await physics_frame
		scene.session.advance_physics(1.0 / 60.0)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/wushuang-attacking.png")
	print("PASS GPU Wushuang: red halo contributes %d pixels; ghosts contribute %d pixels; run/turn/attack screenshots saved" % [halo_pixels, ghost_pixels])
	quit()

func changed_pixels(first: Image, second: Image) -> int:
	var changed := 0
	for y in range(first.get_height()):
		for x in range(first.get_width()):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > 0.04:
				changed += 1
	return changed
#endregion
