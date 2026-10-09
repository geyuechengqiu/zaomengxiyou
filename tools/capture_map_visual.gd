extends SceneTree
#region 原始角色配置的实际GPU地图预览
func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("地图预览需要实际GPU渲染")
		quit(1)
		return
	root.size = Vector2i(940,590)
	var scene := load("res://examples/level_progression_demo.tscn").instantiate() as Node2D
	scene.enable_player_controls = false
	root.add_child(scene)
	current_scene = scene
	scene.session.set_physics_process(false)
	for tick in range(150):
		await physics_frame
		scene.session.advance_physics(1.0/60.0)
	await process_frame
	await RenderingServer.frame_post_draw
	var preview := root.get_texture().get_image()
	var error := preview.save_png("res://addons/battle_foundation/docs/biyujing-preview.png")
	if error != OK: push_error("地图预览保存失败：%s" % error)
	else: print("PASS GPU original map preview: authored original art, initial player attributes and ordinary monsters")
	quit(0 if error == OK else 1)
#endregion
