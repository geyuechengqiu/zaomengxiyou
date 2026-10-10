extends SceneTree
#region 真实GPU验收：原版播报、扇形音符、实体石墙与保护
var scene
var boss

func _initialize() -> void:
	call_deferred("capture")

func tick(delta: float = 1.0/60) -> void:
	await physics_frame
	scene.session.advance_physics(delta)

func shot(name: String) -> void:
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/boss-%s.png" % name)

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Boss画面验收需要真实GPU")
		quit(1)
		return
	root.size = Vector2i(940,590)
	DirAccess.make_dir_recursive_absolute("res://.cleanup-backup")
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	scene.session.set_physics_process(false)
	scene.flow.stop()
	scene.info.text = "孙悟空 · 等级1 · 生命275/275 · 魔法100/100 · 巨石灵君技能画面验收"
	scene.player.position = Vector2(420,1056)
	boss = scene.session.spawn_entity_2d("monsters", &"巨石灵君", Vector2(1000,1056))
	for frame in range(20):
		await tick()
		if boss.attack_instance != null and boss.attack_instance.active: break
	if boss.attack_instance == null or not boss.attack_instance.active:
		push_error("Boss实际AI没有启动琵琶动作")
		quit(1)
		return
	boss.ai_controller.enabled = false
	for frame in range(51): await tick()
	await shot("pipa")
	boss.cancel_skill()
	var profile = boss.ai_controller.boss_profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	profile.skills.remove_at(1)
	profile.skills.remove_at(0)
	boss.ai_controller.boss_profile = profile
	boss.ai_controller.retreat_remaining = 0
	boss.ai_controller.decision_remaining = 0
	boss.ai_controller.group_deadlines.clear()
	boss.ai_controller.enabled = true
	await tick()
	boss.ai_controller.enabled = false
	for frame in range(66): await tick()
	await shot("wall")
	boss.protection.register_hit({"original_skill_id":1101010,"protection_parameters":{"protectPoint":25000}},1,1167)
	await tick()
	await shot("protection")
	scene.session.set_paused(true)
	await tick(10)
	await shot("paused")
	print("PASS GPU stage13: original Boss, authored animations, announcements, fan notes, physical wall and protection screenshots rendered")
	quit()
#endregion
