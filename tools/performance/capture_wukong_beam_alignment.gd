extends SceneTree
#region 正式场景原生渲染：火眼的身体、火光、射线及朝向
var scene

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	root.size = Vector2i(940, 590)
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	scene.session.set_physics_process(false)
	var level_definition = scene.flow.definition
	scene.flow.stop()
	scene.player.position = Vector2(750, 1056)
	scene.player.show_registration = false
	for direction in [1, -1]:
		scene.player.animation.set_facing(direction)
		scene.player.animation.play_action(&"skill3", true)
		scene.player.animation.advance_animation(0.3)
		for angle in [0.0, -30.0, 15.0]:
			var ability = scene.player.abilities.get_ability_instance(&"sunwukong_skill3")
			var timeline = ability.get_feature("BattleFrameTimelineFeature")
			scene.player.animation.apply_skill_aim(timeline, angle)
			for frame in range(3):
				await process_frame
				await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.cleanup-backup/wukong-beam-%d-%d.png" % [direction, int(angle)])
	scene.player.animation.play_action(&"skill3", true)
	scene.player.animation.advance_animation(2.0)
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/wukong-beam-extended.png")
	scene.player.animation.play_action(&"idle", true)
	scene.flow.start(level_definition)
	scene.original_hud._on_event("battle.region.exit_opened", [{"battle_id":scene.session.battle_id,"region_id":scene.session.level_instance.regions[0].definition.region_id}])
	for frame in range(3):
		await process_frame
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.cleanup-backup/region-forward-position.png")
	print("PASS GPU: beam at both facings/aim limits/extended duration and region-forward position captured")
	quit()
#endregion
