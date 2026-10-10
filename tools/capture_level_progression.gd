extends SceneTree
#region 真实GPU画面：区域刷怪、零活怪等待、Boss与通关
var scene

func _initialize() -> void:
	call_deferred("capture")

func tick(delta: float) -> void:
	await physics_frame
	scene.session.advance_physics(delta)

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/level-%s.png" % name)

func kill_targets(skip_vessel: bool = false) -> void:
	for actor in scene.session.get_entities():
		if actor != scene.player and actor.is_alive() and (not skip_vessel or actor.definition_id != &"复苏容器"):
			scene.session.apply_secondary_damage(actor, scene.player, 1000000, &"capture")

func clear_current_region() -> void:
	var region = scene.flow.regions[scene.flow.current_region_index]
	scene.player.position = Vector2(region.definition.entry_rect.get_center().x, 1056)
	for step in range(40):
		await tick(0.1)
		kill_targets()
		if region.exit_open: return
		var next_due := INF
		for plan in scene.flow.plans.values(): next_due = minf(next_due, plan.next_due)
		if is_finite(next_due): await tick(maxf(0.01, next_due-scene.flow.elapsed))

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("关卡画面验收需要真实GPU")
		quit(1)
		return
	root.size = Vector2i(940,590)
	DirAccess.make_dir_recursive_absolute("res://.cleanup-backup")
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	scene.session.set_physics_process(false)
	scene.player.attributes.set_base_value(&"hpMax", 100000)
	scene.player.attributes.get_vital(&"health").set_current_value(100000)
	scene.player.super_armor = true
	for step in range(260): await tick(1.0/60.0)
	await shot("first-wave")
	kill_targets()
	await tick(0.01)
	await shot("between-waves")
	if scene.flow.regions[0].exit_open:
		push_error("等待第二波时误开出口")
		quit(1)
		return
	for index in range(4):
		await clear_current_region()
		var region = scene.flow.regions[index]
		scene.player.position = Vector2(region.definition.exit_rect.get_center().x,1056)
		scene.flow.request_exit(scene.player)
	var last = scene.flow.regions[4]
	scene.player.position = Vector2(last.definition.entry_rect.get_center().x,1056)
	await tick(0.01)
	for step in range(130): await tick(1.0/60.0)
	kill_targets(true)
	for actor in scene.session.get_entities():
		if actor.definition_id == &"复苏容器" and actor.is_alive(): scene.session.apply_secondary_damage(actor,scene.player,1000000,&"capture")
	await tick(0.8)
	await shot("boss-waiting")
	if last.exit_open:
		push_error("Boss尚未生成时误开出口")
		quit(1)
		return
	for step in range(12): await tick(1.0/60.0)
	await shot("boss")
	kill_targets()
	await tick(0.01)
	scene.player.position = Vector2(last.definition.exit_rect.get_center().x,1056)
	if not scene.flow.request_exit(scene.player):
		push_error("最终出口资格校验失败")
		quit(1)
		return
	await shot("victory")
	print("PASS GPU stage12: authored map and actual monsters/Boss rendered; zero-live wave gap and Boss delay keep gates locked; final victory confirmed")
	quit()
#endregion
