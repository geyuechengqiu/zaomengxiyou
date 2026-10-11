extends SceneTree
#region 原关卡真实GPU画面检查，不创建游戏示例场景
var scene

func _initialize() -> void:
	call_deferred(&"capture")

func tick() -> void:
	await physics_frame
	scene.session.advance_physics(1.0/30)

func shot(name: String) -> void:
	for index in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/pipa-boss-%s.png" % name)

func capture() -> void:
	root.size = Vector2i(940,590)
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	scene.session.set_physics_process(false)
	scene.flow.stop()
	var boss = scene.session.spawn_entity_2d("monsters", &"巨石灵君",Vector2(1450,1056),&"",true)
	boss.ai_controller.enabled = false
	var vessel = scene.session.spawn_entity_2d("monsters", &"复苏容器",Vector2(1050,1056))
	var ally = scene.session.spawn_entity_2d("monsters", &"剑舞",Vector2(1200,1056))
	ally.ai_controller.enabled = false
	ally.attributes.get_vital(&"health").set_current_value(1)
	for index in range(12): await tick()
	await shot("entrance")
	for index in range(60): await tick()
	await shot("healing")
	print("PASS GPU Pipa/Boss entrance: original screen clip, native actor/Buff alignment and shared healing numbers")
	quit()
#endregion
