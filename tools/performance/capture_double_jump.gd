extends SceneTree
#region 真实关卡二段跳翻身循环与下落GPU画面
var scene

func _initialize() -> void:
	call_deferred(&"capture")

func tick() -> void:
	await physics_frame
	scene.session.advance_physics(1.0/30.0)

func shot(name: String) -> void:
	for index in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/double-jump-%s.png" % name)

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("二段跳画面检查需要真实GPU")
		quit(1)
		return
	root.size = Vector2i(940,590)
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	scene.session.set_physics_process(false)
	scene.flow.stop()
	scene.player.global_position = Vector2(800,1056)
	for index in range(10): await tick()
	if not scene.player.try_jump():
		push_error("第一跳触发失败")
		quit(1)
		return
	for index in range(4): await tick()
	if not scene.player.try_jump():
		push_error("第二跳触发失败")
		quit(1)
		return
	for index in range(2): await tick()
	await shot("turn-first")
	for index in range(8): await tick()
	await shot("turn-next-cycle")
	for index in range(8): await tick()
	await shot("fall")
	for index in range(35): await tick()
	await shot("land")
	print("PASS double jump GPU: first/next flip cycle, falling and landing captures")
	quit()
#endregion
