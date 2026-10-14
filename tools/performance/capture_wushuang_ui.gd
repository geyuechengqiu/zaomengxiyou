extends SceneTree
#region 真实GPU：原版无双满值/使用/结束的HUD及角色截图
func _initialize() -> void:
	call_deferred("capture")

func snapshot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/wushuang-ui-%s.png" % name)

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("无双UI截图需要真实GPU")
		quit(1)
		return
	root.size = Vector2i(940, 590)
	var scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	scene.session.set_physics_process(false)
	scene.flow.stop()
	var hud = scene.original_hud
	hud.set_process(false)
	for tick in range(8):
		await physics_frame
		scene.session.advance_physics(1.0 / 60.0)
		hud._advance_wushuang_ui(1.0 / 60.0)
	scene.player.wushuang.add_rage(10000)
	hud._advance_wushuang_ui(1)
	await snapshot("full")
	if not scene.player.try_activate_skill(&"sunwukong_wushuang"):
		push_error("满值无双释放失败")
		quit(1)
		return
	scene.player.move_axis = 1
	scene.player.running = true
	for tick in range(45):
		await physics_frame
		scene.session.advance_physics(1.0 / 60.0)
		hud._advance_wushuang_ui(1.0 / 60.0)
	await snapshot("active")
	scene.player.move_axis = 0
	scene.player.wushuang.advance_simulation(6.75)
	hud._advance_wushuang_ui(1)
	await snapshot("half")
	scene.player.statuses.remove_status(&"normal_wushuang_visual")
	hud._advance_wushuang_ui(1)
	await snapshot("empty")
	print("PASS Wushuang UI GPU: full/active/half/empty, original flame/Space frames, red character and ghosts")
	quit()
#endregion
