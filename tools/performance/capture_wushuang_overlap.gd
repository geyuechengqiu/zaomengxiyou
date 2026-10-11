extends SceneTree
#region 真实GPU检查无双待机、移动、停止和翻转，不创建游戏示例
var scene
var tag: String = "after"

func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if not arguments.is_empty(): tag = arguments[0]
	call_deferred(&"capture")

func tick() -> void:
	await physics_frame
	scene.session.advance_physics(1.0 / 30.0)

func shot(name: String) -> void:
	for index in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/wushuang-%s-%s.png" % [tag,name])

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("无双画面检查需要真实GPU")
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
	scene.player.wushuang.add_rage(10000)
	if not scene.player.try_activate_skill(&"sunwukong_wushuang"):
		push_error("无双释放失败")
		quit(1)
		return
	for index in range(40): await tick()
	await shot("idle")
	scene.player.move_axis = 1
	scene.player.running = true
	for index in range(15): await tick()
	await shot("moving")
	scene.player.move_axis = 0
	for index in range(10): await tick()
	await shot("stopped")
	scene.player.animation.set_facing(-1)
	for index in range(6): await tick()
	await shot("turned")
	scene.player.statuses.remove_status(&"normal_wushuang_visual")
	for index in range(31): await tick()
	await shot("ended")
	print("PASS Wushuang GPU: idle/moving/stopped/turned/ended captures")
	quit()
#endregion
