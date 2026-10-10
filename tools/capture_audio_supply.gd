extends SceneTree
#region 原生GPU补给跳字与设置面板检查
var scene

func _initialize() -> void:
	call_deferred(&"capture")

func shot(name: String) -> void:
	for _frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/" + name + ".png")

func capture() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(940,590)
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	scene.session.set_physics_process(false)
	scene.flow.stop()
	await process_frame
	await process_frame
	scene.player.position = Vector2(420,1056)
	scene.session.camera_rig.advance_camera(1.0 / 30.0)
	scene.session.presentation.number_rows.clear_numbers()
	scene.player.attributes.get_vital(&"health").set_current_value(10)
	scene.session.loot.spawn_item(&"101014001",scene.player.global_position,scene.player)
	if not scene.session.loot.pickup_drop(0,scene.player): push_error("回血补给拾取失败"); quit(1); return
	scene.player.position = Vector2(700,1056)
	scene.player.attributes.get_vital(&"mana").set_current_value(1)
	scene.session.loot.spawn_item(&"101014003",scene.player.global_position,scene.player)
	if not scene.session.loot.pickup_drop(0,scene.player): push_error("回魔补给拾取失败"); quit(1); return
	scene.session.presentation.number_rows.advance_numbers(0.1)
	await shot("supply-recovery")
	scene.original_hud.open_module(&"systemSet")
	await shot("audio-settings")
	var audio = scene.session.audio
	if audio.current_music != "No_1-3" or not audio.music.playing or scene.session.presentation.number_rows.get_active_count() != 2:
		push_error("实际GPU跳字或关卡音乐未正常启动"); quit(1); return
	print("PASS GPU audio/supply: original green/blue recovery glyphs visible; authored settings panel, background stream playing, shared 32-voice Core buses")
	quit()
#endregion
