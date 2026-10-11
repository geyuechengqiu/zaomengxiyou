extends SceneTree
var scene

func _initialize() -> void:
	call_deferred(&"capture")

func tick(delta: float = 1.0 / 30.0) -> void:
	await physics_frame
	scene.session.advance_physics(delta)

func shot(name: String) -> void:
	for index in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/super-armor-%s.png" % name)

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("描边画面检查需要真实GPU")
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
	var monster = scene.session.spawn_entity_2d("monsters", &"剑舞")
	monster.ai_controller.enabled = false
	monster.global_position = Vector2(950,1056)
	monster.animation.set_facing(-1)
	var buff = load("res://data/buffs/super_armor.tres").duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	buff.duration = 10
	scene.player.statuses.apply_status(buff,scene.player)
	monster.statuses.apply_status(buff,monster)
	await tick()
	await shot("red")
	for index in range(10): await tick()
	await shot("yellow")
	scene.player.animation.set_facing(-1)
	scene.player.animation.advance_status_visuals(0)
	await shot("flipped")
	scene.player.wushuang.add_rage(10000)
	scene.player.try_activate_skill(&"sunwukong_wushuang")
	for index in range(10): await tick()
	await shot("wushuang-priority")
	scene.player.statuses.remove_status(&"normal_wushuang_visual")
	scene.player.statuses.remove_status(buff.status_id)
	monster.statuses.remove_status(buff.status_id)
	for index in range(31): await tick()
	await shot("cleared")
	# 直接检查未经测试覆写的角色属性，避免样例初始化掩盖开局问题。
	var power = scene.player.attributes.get_fight_power()
	if power != 987 or scene.player.attributes.get_value(&"reMP") != 0:
		push_error("Actual initial power expected987: " + str(power))
		quit(1)
		return
	scene.original_hud.set_inventory_open(true)
	await shot("initial-inventory-987")
	print("PASS Armor GPU: red/yellow/flipped/Wushuang/cleared and actual initial inventory987")
	quit()
