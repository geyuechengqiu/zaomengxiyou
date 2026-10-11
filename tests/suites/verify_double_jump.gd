extends Node
#region 原生Spine二段跳与真实运动状态衔接
var scene: Node2D
var session: BattleSession
var player: BattleEntity2D
var adapter: SpineAnimationAdapter
var sprite: SpineSprite
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func tick(delta: float) -> void:
	await get_tree().physics_frame
	session.advance_physics(delta)

func _ready() -> void:
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	add_child(scene)
	session = scene.session
	player = scene.player
	adapter = player.animation as SpineAnimationAdapter
	sprite = adapter.get_node("SpineVisual") as SpineSprite
	session.set_physics_process(false)
	scene.flow.stop()
	# 本次测试的物理参数独立，不修改用户编辑的共享角色配置。
	player.action_profile = player.action_profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	player.action_profile.gravity = 2000
	player.action_profile.jump_velocity = -1000
	player.action_profile.second_jump_velocity = -1000
	player.global_position = Vector2(800,1056)
	await tick(0.1)
	var evidence: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/characters/sunwukong/animation/double_jump_source.json"))
	check(evidence.duration_frames == 8 and evidence.source_fps == 30 and evidence.play_times == 0, "原龙骨jumpTwo为8帧/30FPS、playTimes=0循环")
	var master := adapter.get_animation_player().get_animation(&"jump_2")
	check(is_equal_approx(master.length,8.0/30.0) and master.loop_mode == Animation.LOOP_LINEAR, "主AnimationPlayer按原8帧时长循环二段跳")
	check(master.track_get_key_count(0) == 1 and master.track_get_key_value(0,0) == &"jumpTwo_looped", "仅绑定循环jumpTwo，不提前插入jumpDown")
	check(player.motion.grounded and player.try_jump(), "地面按跳跃进入第一跳")
	check(adapter.get_current_action() == &"jump" and not sprite.get_animation_state().get_track(0).get_loop(), "第一跳仍播放单次jumpNormal")
	await tick(0.1)
	check(player.try_jump() and player.motion.jump_count == 2, "空中再次按跳跃进入第二跳")
	check(adapter.get_current_action() == &"jump_2" and sprite.get_animation_state().get_track(0).get_animation().get_name() == "jumpTwo", "第二跳立即重启原生翻身动画")
	check(sprite.get_animation_state().get_track(0).get_loop(), "原生Spine二段跳循环标记开启")
	await tick(0.32)
	check(player.velocity.y < 0 and adapter.get_current_action() == &"jump_2" and sprite.get_animation_state().get_track(0).get_animation().get_name() == "jumpTwo", "超过一轮仍在上升，持续翻身而非提前下落")
	check(adapter.get_animation_player().is_playing() and adapter.get_playback_time() < master.length, "一轮结束后主动画继续播放并回绕时间")
	var position := player.global_position
	var pose_time := sprite.get_animation_state().get_track(0).get_track_time()
	session.set_paused(true)
	await tick(1)
	check(player.global_position == position and sprite.get_animation_state().get_track(0).get_track_time() == pose_time, "暂停同时冻结第二跳运动与动画")
	session.set_paused(false)
	check(not player.try_jump(), "循环播放动画不会重新授予第三次跳跃")
	await tick(0.25)
	check(player.velocity.y > 0 and adapter.get_current_action() == &"fall" and sprite.get_animation_state().get_track(0).get_animation().get_name() == "jumpDown", "真正转为下落时由动作状态切换jumpDown")
	check(not sprite.get_animation_state().get_track(0).get_loop(), "下落动画不继承二段跳循环标记")
	await tick(1)
	check(player.motion.grounded and player.motion.jumps_used == 0 and adapter.get_current_action() in [&"land",&"idle"], "真实落地后恢复地面表现及跳跃预算")
	_verify_pose_cycles(master.length)
	scene.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS original double jump: %d checks; original8/30 infinite loop, native poses, first/second/fall/landing, no third jump, pause and 15/30/60FPS/large delta" % checks)
	else:
		for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)

func _verify_pose_cycles(duration: float) -> void:
	adapter.play_action(&"jump_2",true)
	adapter.advance_animation(0.04)
	var first_pose := sprite.get_skeleton().get_bounds()
	adapter.advance_animation(duration*2)
	check(is_equal_approx(adapter.get_playback_time(),0.04) and sprite.get_skeleton().get_bounds().is_equal_approx(first_pose), "两轮后回到同一原生姿态，不冻结终帧或跳到下落")
	for hz in [15,30,60]:
		adapter.play_action(&"jump_2",true)
		for frame in range(hz): adapter.advance_animation(1.0/hz)
		check(absf(adapter.get_playback_time()-fmod(1.0,duration)) < 0.0001 and sprite.get_animation_state().get_track(0).get_animation().get_name() == "jumpTwo", "不同更新率保留30源帧循环时序："+str(hz))
	adapter.play_action(&"jump_2",true)
	adapter.advance_animation(1.1)
	check(absf(adapter.get_playback_time()-fmod(1.1,duration)) < 0.0001 and adapter.get_animation_player().is_playing(), "大delta跨多轮仍按原周期播放")
#endregion
