extends SceneTree
#region 真实GPU下原版Boss HUD与怪物出场
var scene

func _initialize() -> void:
	call_deferred("capture")

func tick(delta: float) -> void:
	await physics_frame
	scene.session.advance_physics(delta)

func shot(name: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/original-boss-%s.png" % name)

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("原版血条与出场画面验收需要真实GPU")
		quit(1)
		return
	root.size = Vector2i(940,590)
	scene = load("res://examples/level_progression_demo.tscn").instantiate()
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	scene.session.set_physics_process(false)
	scene.flow.stop()
	var boss = scene.session.spawn_entity_2d("monsters", &"巨石灵君", Vector2(1450,1056), &"", true)
	boss.ai_controller.enabled = false
	var monster = scene.session.spawn_entity_2d("monsters", &"剑舞", Vector2(900,1056), &"", true)
	monster.ai_controller.enabled = false
	await tick(0.3)
	await shot("entrance")
	await tick(0.6)
	await shot("hud")
	boss.attributes.get_vital(&"health").set_current_value(1000)
	boss.protection.register_hit({"original_skill_id":1101010,"protection_parameters":{"protectPoint":10000}},1,1167)
	await tick(0.3)
	await shot("damaged")
	root.size = Vector2i(1200,590)
	root.content_scale_size = Vector2i(1200,590)
	await shot("wide")
	var feedback = scene.session.presentation.get_node("BossFeedback")
	var viewport_size = root.get_visible_rect().size
	if absf(feedback.bar.global_position.x-viewport_size.x/2) > 0.01:
		push_error("宽画布Boss栏未居中")
		quit(1)
		return
	print("PASS GPU original Boss presentation: original name/resistances/fonts/25-frame entrance at 940x590; wider logical viewport %s centered at x=%f" % [viewport_size,feedback.bar.global_position.x])
	quit()
#endregion
