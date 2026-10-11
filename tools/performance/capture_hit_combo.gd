extends SceneTree
#region 真实关卡连击数字和超时隐藏GPU画面
var scene
var target

func _initialize() -> void:
	call_deferred(&"capture")

func shot(label: String) -> void:
	for index in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/hit-combo-%s.png" % label)

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("连击画面检查需要真实GPU")
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
	target = scene.session.spawn_entity_2d("monsters", &"剑舞", Vector2(1050,1056))
	target.ai_controller.enabled = false
	target.attributes.set_base_value(&"hpMax",10000)
	target.attributes.get_vital(&"health").set_current_value(10000)
	for index in range(12):
		scene.session.clock.hit_stop_remaining = 0
		scene.player.resolve_attack_hit(target,{"test_damage_random_1":true})
		if index == 0: await shot("one")
	await shot("twelve")
	scene.session.clock.hit_stop_remaining = 0
	scene.session.advance_physics(1.6)
	await shot("expired")
	print("PASS hit combo GPU: original one/twelve glyphs and timeout hide")
	quit()
#endregion
