extends "res://examples/original_damage_demo.gd"
#region 真实预置场景中的GPU画面验收
func _ready() -> void:
	super._ready()
	session.set_physics_process(false)
	operations.enabled = false
	var sample := "run_attack"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sample="):
			sample = arg.get_slice("=", 1)
	for tick in range(8):
		await get_tree().physics_frame
		session.advance_physics(1.0 / 60.0)
	match sample:
		"run_attack":
			player.move_axis = 1.0
			player.running = true
			session.advance_physics(1.0 / 60.0)
			assert(player.request_attack())
		"jump_attack":
			assert(player.try_jump() and player.request_attack())
		"attack4_turn":
			assert(player.try_activate_skill(&"sunwukong_attack4"))
		_:
			push_error("Unknown capture sample")
			get_tree().quit(1)
			return
	var ticks := 12 if sample == "jump_attack" else (16 if sample == "attack4_turn" else 8)
	for tick in range(ticks):
		await get_tree().physics_frame
		session.advance_physics(1.0 / 60.0)
	if sample == "attack4_turn":
		assert(player.try_turn_combo(-1))
		for tick in range(4):
			await get_tree().physics_frame
			session.advance_physics(1.0 / 60.0)
	_process(0.0)
	set_process(false)
	await RenderingServer.frame_post_draw
	var path := "res://addons/battle_foundation/docs/wukong-" + sample + ".png"
	assert(get_viewport().get_texture().get_image().save_png(path) == OK)
	print("PASS GPU Wukong capture ", sample, " state=", player.action_state.get_name(), " facing=", player.animation.get_facing(), " velocity=", player.velocity)
	get_tree().quit()
#endregion
