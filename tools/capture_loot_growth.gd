extends SceneTree
#region 原生GPU检查灵魂、死亡隐藏、掉落与强化背包
var scene: Node2D
## SceneTree --script在autoload之前编译，业务类只在capture中动态加载。
var session

func _initialize() -> void:
	call_deferred(&"capture")

func tick(delta: float) -> void:
	await physics_frame
	session.advance_physics(delta)

func shot(name: String) -> void:
	for _frame in range(3):
		if scene.original_hud.inventory_view.visible:
			var view = scene.original_hud.inventory_view
			view.get_node("RolePortrait").advance_animation(1.0 / 60.0)
			view.get_node("PortraitGlow").advance_effect(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/stage14-%s.png" % name)

func capture() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	root.size = Vector2i(940, 590)
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	session = scene.session
	session.set_physics_process(false)
	scene.flow.stop()
	for entity in session.get_entities():
		if entity.has_node("AIController"): entity.ai_controller.enabled = false
	scene.player.position = Vector2(420, 1056)
	var monster = session.spawn_entity_2d("monsters", &"剑舞", Vector2(650, 1056))
	monster.ai_controller.enabled = false
	for _frame in range(8): await tick(1.0 / 60.0)
	await shot("before")
	session.apply_secondary_damage(monster, scene.player, 1000, &"periodic")
	await tick(0.2)
	await shot("soul-rise")
	await tick(0.3)
	await shot("soul-trail")
	for _frame in range(16): await tick(0.2)
	if monster.visible or not session.loot.souls.is_empty(): push_error("Dead monster or completed soul remains visible"); quit(1); return
	session.loot.spawn_item(&"110101001", Vector2(600, 1056), scene.player)
	await tick(0.5)
	await shot("ground-drop")
	var feedback = scene.original_hud.get_node("PickupEffects")
	feedback.set_process(false)
	feedback.clear_effects()
	var ground_index = -1
	for index in range(session.loot.drops.size()):
		if session.loot.drops[index].item.item_id == &"110101001": ground_index = index; break
	if ground_index < 0 or not session.loot.pickup_drop(ground_index, scene.player): push_error("Ground equipment failed to enter bag"); quit(1); return
	if feedback.flights.size() != 1: push_error("Equipment pickup flight missing"); quit(1); return
	await shot("pickup-start")
	var flight_duration = feedback.flights[0].duration
	feedback.advance_effects(flight_duration / 2.0)
	await shot("pickup-half")
	feedback.advance_effects(flight_duration)
	if not feedback.flights.is_empty(): push_error("Completed pickup flight remains"); quit(1); return
	feedback.set_process(true)
	var bag = scene.player.inventory
	var weapon = bag.get_owned_item(load("res://data/inventory/110101003.tres"))
	bag.equip_item(weapon)
	bag.grant_spirit(10)
	bag.add_item(session.loot.catalog.get_definition(&"101005001"))
	if not bag.apply_growth(weapon, &"enhance"): push_error("Original enhancement failed"); quit(1); return
	scene.original_hud.set_inventory_open(true)
	var view = scene.original_hud.inventory_view
	var nickname = view.get_node("Name")
	nickname.text = "悟空"
	nickname.select_all()
	nickname.grab_focus()
	var key = InputEventKey.new()
	key.keycode = KEY_B
	key.unicode = 98
	key.pressed = true
	root.push_input(key)
	await process_frame
	if not view.visible or bag.display_name != "b": push_error("Nickname typing closed the bag or did not rename"); quit(1); return
	bag.set_display_name("悟空测试")
	nickname.release_focus()
	# 截图没有鼠标悬停；冻结视图的关闭检测以保留已打开菜单。
	view.set_process(false)
	var armor = bag.get_owned_item(load("res://data/inventory/110101001.tres"))
	view._open_context(armor, false, view.get_node("Grid/Slot0"))
	await shot("growth-menu")
	if not view.get_node("Context").visible: push_error("Growth context is not visible"); quit(1); return
	view.get_node("Context").hide()
	view._show_item_tip(weapon, view.get_node("Equipment/Part1"), true)
	await shot("growth-tooltip")
	print("PASS GPU stage14: original soul/trail, ground quality glow, Cubic pickup flight to bag, unified equipment icons/borders, nickname typing, three-action menu and outlined tooltip captured")
	session.clear_battle()
	quit()
#endregion
