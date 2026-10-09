extends SceneTree
#region 真实GPU画面检查，不用运行时替代正式场景节点
var scene
var boss

func _initialize() -> void:
	call_deferred("capture")

func tick(delta: float) -> void:
	await physics_frame
	scene.session.advance_physics(delta)

func shot(name: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/battle-ui-%s.png" % name)

func capture() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(940,590)
	scene = load("res://examples/level_progression_demo.tscn").instantiate()
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	scene.session.set_physics_process(false)
	scene.flow.stop()
	scene.player.position = Vector2(420,1056)
	boss = scene.session.spawn_entity_2d("monsters", &"巨石灵君", Vector2(1000,1056))
	boss.ai_controller.enabled = false
	scene.session.presentation.get_node("BossFeedback").sound_enabled = false
	await tick(0.1)
	await shot("hud")
	var pixels = root.get_texture().get_image()
	if pixels.get_pixel(110,26).r < 0.65 or pixels.get_pixel(110,40).b < 0.3:
		push_error("Original HP/MP fill is occluded by the HUD background")
		quit(1)
		return
	scene.player.attributes.get_vital(&"health").set_current_value(268)
	scene.player.attributes.get_vital(&"mana").set_current_value(57)
	scene.player.attributes.set_experience(55)
	await shot("hud-partial")
	pixels = root.get_texture().get_image()
	var exp_pixel = pixels.get_pixel(110,54)
	if exp_pixel.r < 0.5 or exp_pixel.g < 0.3 or exp_pixel.b > 0.3:
		push_error("Original golden EXP fill is occluded or uses the wrong texture")
		quit(1)
		return
	scene.player.attributes.get_vital(&"mana").set_current_value(0)
	await shot("no-mana")
	scene.player.attributes.get_vital(&"mana").set_current_value(100)
	var profile = boss.ai_controller.boss_profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	var wall_rule = profile.skills[2]
	profile.skills.clear()
	profile.skills.append(wall_rule)
	boss.ai_controller.boss_profile = profile
	boss.ai_controller.enabled = true
	await tick(0.01)
	boss.ai_controller.enabled = false
	await tick(1.1)
	await shot("wall-announcement")
	scene.original_hud._cooldowns[0].start_cooldown(scene.original_hud._abilities[0])
	scene.original_hud._cooldowns[0].update(scene.original_hud._abilities[0],2)
	await shot("cooldown")
	scene.original_hud.set_inventory_open(true)
	await shot("inventory")
	var weapon = scene.player.inventory.get_bag_items("equipment")[2]
	scene.player.inventory.equip_item(weapon)
	scene.original_hud.inventory_view._show_item_tip(weapon)
	await shot("equipped-tooltip")
	var bag_view = scene.original_hud.inventory_view
	bag_view.get_node("Tooltip").hide()
	bag_view.get_node("Resistances").show()
	await shot("resistances")
	bag_view.get_node("Resistances").hide()
	bag_view._open_context(scene.player.inventory.get_bag_items("equipment")[0], false)
	bag_view._sell_selected()
	await shot("sell-confirmation")
	bag_view.get_node("Confirm").hide()
	scene.original_hud.show_notification("原版提示：背包操作已更新")
	await shot("notification-inventory")
	scene.original_hud.set_inventory_open(false)
	boss.attributes.get_vital(&"health").set_current_value(0)
	await tick(0.4)
	await shot("execution")
	await tick(2)
	scene.player.position = Vector2(9580,1056)
	scene.get_node("BattleSession/Actors").set_final_exit_open(true)
	scene.session.camera_rig.set_region_bounds(Rect2(8896,0,2048,1216),true)
	await tick(0.3)
	await shot("gateway")
	print("PASS GPU: battle HUD, cooldown, backpack/equipment/tooltip/resistances/confirmation/notification, original wall/announcement, execution and gateway captured")
	quit()
#endregion
