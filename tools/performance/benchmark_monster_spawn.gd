extends Node
#region 真实关卡出生成本；在同一引擎与渲染模式下比较
var samples: Dictionary = {}
var render_frames: Array[float] = []

func _ready() -> void:
	var level: Node2D = load("res://game/levels/biyujing.tscn").instantiate()
	level.enable_player_controls = false
	add_child(level)
	var session: BattleSession = level.session
	session.set_physics_process(false)
	session.profile_spawns = true
	level.flow.stop()
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		for frame in range(30): await RenderingServer.frame_post_draw
	for id: StringName in session.catalog.get_ids("monsters"):
		var clones: Array[float] = []
		var births: Array[float] = []
		var stages: Dictionary = {}
		for index in range(12):
			var started := Time.get_ticks_usec()
			var definition := session.catalog.instantiate_definition("monsters",id)
			clones.append((Time.get_ticks_usec()-started)/1000.0)
			definition = null
			started = Time.get_ticks_usec()
			var actor := session.spawn_entity_2d("monsters",id,Vector2(1200,1056),&"",true)
			births.append((Time.get_ticks_usec()-started)/1000.0)
			stages = session.last_spawn_profile.duplicate()
			if actor == null:
				push_error(session.last_error)
				get_tree().quit(1)
				return
			actor.ai_controller.enabled = false
			stages.merge(actor.last_ready_profile)
			if DisplayServer.get_name() != "headless":
				var drawn_at := Time.get_ticks_usec()
				for frame in range(3):
					await RenderingServer.frame_post_draw
					render_frames.append((Time.get_ticks_usec()-drawn_at)/1000.0)
					drawn_at = Time.get_ticks_usec()
			await get_tree().process_frame
			await get_tree().process_frame
			session.despawn_entity(actor.entity_id)
			await get_tree().process_frame
		samples[String(id)] = {"definition_copy_ms":stats(clones),"spawn_ms":stats(births),"last_stages":stages}
	print("BENCH monster spawn: ",JSON.stringify(samples))
	if not render_frames.is_empty(): print("BENCH render frame ms: ",JSON.stringify(stats(render_frames)))
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		session.presentation.advance_presentation(0)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://.cleanup-backup/latest-level-organized.png")
	var file := FileAccess.open("res://.cleanup-backup/monster-spawn-latest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(samples,"\t"))
	level.free()
	await get_tree().process_frame
	print("PASS monster spawn benchmark")
	get_tree().quit()

func stats(values: Array[float]) -> Dictionary:
	var ordered := values.duplicate()
	ordered.sort()
	var total := 0.0
	for value in values: total += value
	return {"first":values[0],"mean":total/values.size(),"p95":ordered[ceili(values.size()*0.95)-1],"max":ordered[-1]}
#endregion
