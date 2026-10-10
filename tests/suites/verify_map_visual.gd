extends Node
#region 原素材、连续地图与预置模板
var demo: Node2D
var map: BattleMap2D
var visual: BattleMapVisual2D
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children(): count += nodes(child)
	return count

func step(delta: float) -> void:
	await get_tree().physics_frame
	demo.session.advance_physics(delta)

func _ready() -> void:
	demo = load("res://game/levels/biyujing.tscn").instantiate()
	demo.enable_player_controls = false
	var authored := nodes(demo.get_node("BattleSession/Actors/Visuals/BiyujingVisual")) + nodes(demo.get_node("BattleSession/Actors/Terrain")) + nodes(demo.get_node("BattleSession/Actors/SpawnPoints"))
	add_child(demo)
	demo.session.set_physics_process(false)
	map = demo.get_node("BattleSession/Actors") as BattleMap2D
	visual = map.get_node("Visuals/BiyujingVisual") as BattleMapVisual2D
	check(nodes(visual) + nodes(map.get_node("Terrain")) + nodes(map.get_node("SpawnPoints")) == authored, "背景、地面、遮挡、云动画与地图骨架均预置，启动不创建地图节点")
	check(map != null and map.world_bounds == Rect2(0,0,10944,1216), "整关五区域使用唯一连续地图根")
	check(visual != null and visual.get_node("ForegroundOccluders").get_child_count() == 6, "六处原近景遮挡物同在整张地图")
	check(map.get_node("Terrain").get_child_count() == 13 and map.get_node("SpawnPoints").get_child_count() == 17, "原碰撞与出生点保留")
	check(not demo.has_node("Mountains") and not demo.has_node("Background"), "移除测试背景和山体")
	for body in map.get_node("Terrain").get_children(): check(not body.has_node("Visual"), "原美术代替碰撞体纯色显示")
	var last := 0.0
	for region: BattleRegionInstance in demo.flow.regions:
		check(region.definition.bounds.position.x == last, "区域边界在同一坐标系连续相接")
		last = region.definition.bounds.end.x
	check(last == map.world_bounds.end.x, "最后区域终点等于整图终点")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/biyujing/original_source.json"))
	check(data.textures.size() == 6 and data.layers.size() == 11 and data.authored_sprites == 16, "完整六种原素材、十一层与十六个预置Sprite")
	check(data.cloud_animation.source_frames == 201 and data.cloud_animation.frames.size() == 603, "原云层201帧、三个独立变换完整保留")
	var floor := visual.get_node("GroundArtwork")
	check(floor.get_child_count() == 5, "四次地板拼接及Boss末段地板")
	for index in range(1,4):
		var previous := floor.get_child(index-1) as Sprite2D
		var current := floor.get_child(index) as Sprite2D
		check(current.position.x == previous.position.x+previous.texture.get_width()*2, "重复地板无缝相接")
	check(floor.get_child(4).position.x == 7974, "末段原3987源像素位置，保留1源像素搭接")
	check(visual.get_node("FarBackground").z_index < visual.get_node("MiddleBackground").z_index and visual.get_node("GroundArtwork").z_index < 0 and visual.get_node("ForegroundOccluders").z_index > 0, "背景/地板在角色后，近景在角色前")
	_verify_parallax()
	demo.flow.stop()
	await _verify_time_and_occlusion()
	await _verify_isolation()
	if failures.is_empty(): print("PASS continuous map art: %d checks; original six textures/11 layers/201-frame clouds, authored reusable templates, five regions on one map, parallax origin/zoom/clamp, seams, occlusion, clocks/isolation/cleanup" % checks)
	else:
		for failure in failures: push_error(failure)
	demo.free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
#endregion
#region 视差左上角、镜头缩放与限界
func _verify_parallax() -> void:
	demo.camera.limit_right = 10944
	for zoom in [0.5,0.75,1.0]:
		for x in [0,3000,10000,20000]:
			demo.camera.zoom = Vector2(zoom,zoom)
			demo.camera.position = Vector2(x,590)
			demo.camera.force_update_scroll()
			visual.refresh_view()
			var left := visual.get_canvas_transform().affine_inverse()*Vector2.ZERO
			for pair in [["FarBackground/far_0_0",0.04],["MiddleBackground/middle_1_0",0.1]]:
				var sprite := visual.get_node(pair[0]) as Sprite2D
				var actual := sprite.get_global_transform_with_canvas().origin.x
				check(is_equal_approx(actual,-left.x*zoom*float(pair[1])), "视差使用可见左界，不在缩放后留下空白：%s/%s/%s" % [pair[0],zoom,x])
			var fixed := visual.get_node("FixedMiddle/CloudMotion") as Node2D
			check(absf(fixed.get_global_transform_with_canvas().origin.x) < 0.01, "isFixedX云层保持在画面左边（允许世界大坐标浮点误差）")
	demo.camera.zoom = Vector2(0.5,0.5)
	demo.camera.position = Vector2(940,590)
	demo.camera.force_update_scroll()
	var far := visual.get_node("FarBackground") as Parallax2D
	far.repeat_size = Vector2(2880,0)
	far.scroll_offset = Vector2(120,0)
	demo.camera.position.x = 10000
	demo.camera.force_update_scroll()
	visual.refresh_view()
	var left := visual.get_canvas_transform().affine_inverse()*Vector2.ZERO
	check(is_equal_approx(far.position.x,left.x-fposmod(left.x*0.04-120,2880)), "模板支持原生重复背景，不把窗口中心带入循环偏移")
	check(far.scroll_offset == Vector2(120,0), "原生Scroll Offset编辑值被保留")
	far.repeat_size = Vector2.ZERO
	far.scroll_offset = Vector2.ZERO
	demo.camera.position.x = 940
	demo.camera.force_update_scroll()
#endregion
#region 云层时钟、遮挡、实例独立与清理
func _verify_time_and_occlusion() -> void:
	var player := visual.get_node("FixedMiddle/CloudMotion/AnimationPlayer") as AnimationPlayer
	check(player.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL, "地图动画使用现有BattleClock手动驱动")
	await step(0.25)
	check(is_equal_approx(player.current_animation_position,0.25), "一个战斗tick只推进一次云动画")
	demo.session.set_paused(true)
	await step(10)
	check(is_equal_approx(player.current_animation_position,0.25), "暂停冻结云动画")
	demo.session.set_paused(false)
	demo.session.set_time_scale(0.5)
	await step(1)
	check(is_equal_approx(player.current_animation_position,0.75), "云动画随战斗慢动作")
	demo.session.set_time_scale(1)
	demo.session.request_hit_stop(0.2)
	var before := player.current_animation_position
	await step(0.1)
	check(player.current_animation_position == before, "受击停顿冻结云动画")
	await step(0.2)
	check(is_equal_approx(player.current_animation_position,before+0.1), "停顿结束只推进剩余时间")
	var near := visual.get_node("ForegroundOccluders/near_10_0") as BattleMapOccluder2D
	demo.player.position = Vector2(530,1056)
	visual.refresh_occlusion()
	check(near.self_modulate.a == 0.5, "玩家进入近景遮挡矩形时采用原barrierAlpha")
	demo.player.position.x = 1200
	visual.refresh_occlusion()
	check(near.self_modulate.a == 1.0, "玩家离开近景后恢复透明度")
	var enemy: BattleEntity2D = demo.session.spawn_entity_2d("monsters",&"剑舞",Vector2(530,1056))
	visual.refresh_occlusion()
	check(near.self_modulate.a == 1.0, "敌方怪物不触发原玩家遮挡分支")
	demo.session.despawn_entity(enemy.entity_id)
	await get_tree().process_frame

func _verify_isolation() -> void:
	var other := load("res://data/levels/biyujing/progression/visual.tscn").instantiate() as BattleMapVisual2D
	add_child(other)
	var original := visual.get_node("FixedMiddle/CloudMotion/AnimationPlayer") as AnimationPlayer
	var clone := other.get_node("FixedMiddle/CloudMotion/AnimationPlayer") as AnimationPlayer
	var before := original.current_animation_position
	other.advance_visuals(2)
	check(original.current_animation_position == before and is_equal_approx(clone.current_animation_position,2), "相同视觉资源的播放进度独立")
	check(other.get_node("GroundArtwork/ground_repeat_3_0").texture == visual.get_node("GroundArtwork/ground_repeat_3_0").texture, "静态贴图共享，不重复拷贝大图片")
	var callback := Callable(other,"refresh_view")
	check(RenderingServer.frame_pre_draw.is_connected(callback), "视口刷新绑定预置地图")
	other.free()
	check(not RenderingServer.frame_pre_draw.is_connected(callback), "离场断开渲染订阅")
#endregion
