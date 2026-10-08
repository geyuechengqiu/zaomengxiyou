extends Node
#region 验收入口与断言
var checks: int = 0
var failures: Array[String] = []
var visual: SpineAnimationAdapter
var primary: SpineSprite
var secondary: SpineSprite

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)

func _ready() -> void:
	visual = (load("res://data/animation/sunwukong_visual.tscn") as PackedScene).instantiate()
	primary = visual.get_node("AttackEffects/Primary")
	secondary = visual.get_node("AttackEffects/Secondary")
	_check(primary.get_node("SpineAnimationTrack/AnimationPlayer") != null, "特效播放器在进入场景树前已预置")
	add_child(visual)
	_check(visual.last_error.is_empty(), "原生特效与角色初始化成功")
	_verify_timing()
	_verify_facing_and_isolation()
	_verify_cancel_and_restart()
	_verify_attachment_isolation()
	await _verify_battle_clock()
	visual.free()
	if failures.is_empty():
		print("PASS wukong attack effects: %d checks; original combo/context effects, native poses, low FPS, facing, cancellation, instance isolation and combat clock" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
#endregion
#region 连续切段与重复连击不继承旧槽位及网格
func _attachments(sprite: SpineSprite) -> Dictionary:
	var result := {}
	for slot in sprite.get_skeleton().get_slots():
		var attachment: SpineAttachment = slot.get_pose().get_attachment()
		if attachment != null:
			result[slot.get_data().get_name()] = attachment.get_attachment_name()
	return result

func _check_effect_pose(actual: SpineAnimationAdapter, action: StringName, time: float, label: String) -> void:
	var fresh := (load("res://data/animation/sunwukong_visual.tscn") as PackedScene).instantiate() as SpineAnimationAdapter
	add_child(fresh)
	fresh.play_action(action, true)
	fresh.advance_animation(time)
	for name in ["Primary", "Secondary"]:
		var reused := actual.get_node("AttackEffects/" + name) as SpineSprite
		var expected := fresh.get_node("AttackEffects/" + name) as SpineSprite
		_check(_attachments(reused) == _attachments(expected), "%s / %s：附件与全新实例一致，没有旧攻击槽位" % [label, name])
		if reused.visible:
			_check(reused.get_skeleton().get_bounds().is_equal_approx(expected.get_skeleton().get_bounds()), "%s / %s：实际绘制范围与全新实例一致" % [label, name])
		else:
			_check(_attachments(reused).is_empty(), "%s / %s：停止后恢复空附件初始姿态" % [label, name])
	fresh.free()

func _verify_attachment_isolation() -> void:
	# 不经过待机连续切段，再反向切回，覆盖合并骨架各动画只键控自身槽位。
	var samples := [[&"attack_1", 0.2], [&"attack_2", 0.2], [&"attack_3", 0.16],
		[&"attack_4", 0.1], [&"attack_4", 0.35], [&"attack_5", 0.27],
		[&"attack_2", 0.2], [&"attack_1", 0.2], [&"run_attack", 0.21], [&"jump_attack", 0.28], [&"attack_4", 0.35], [&"run_attack", 0.15], [&"idle", 0.0]]
	for facing in [1, -1]:
		visual.set_facing(facing)
		for sample in samples:
			visual.play_action(sample[0], true)
			visual.advance_animation(sample[1])
			_check_effect_pose(visual, sample[0], sample[1], "朝向%d / %s" % [facing, sample[0]])
	visual.set_facing(1)
#endregion
#region 原版30帧时间与六个特效窗口
func _verify_timing() -> void:
	var starts: Array[int] = [4, 4, 2, 0, 6]
	var durations: Array[int] = [8, 7, 10, 8, 9]
	for index in range(5):
		var action := StringName("attack_%d" % (index + 1))
		var start := starts[index] / 30.0
		var end := minf(visual.get_action_duration(action), start + durations[index] / 30.0)
		for time in [0.0, maxf(0.0, start - 0.001), start + 0.001, (start + end) / 2.0, end - 0.001, end + 0.001]:
			visual.play_action(action, true)
			visual.advance_animation(time)
			var expected: bool = time >= start and time < end
			_check(primary.visible == expected, "原版窗口 %s @ %.4f" % [action, time])
			var entry := primary.get_animation_state().get_track(0)
			if expected:
				_check(entry != null and entry.get_animation().get_name() == "attack%d" % (index + 1), "选择现有骨架中的原版特效")
				_check(entry != null and absf(entry.get_track_time() - (time - start)) < 0.001, "跨越触发帧仍精确同步特效局部时间")
			else:
				_check(entry == null, "窗口外不残留特效轨道：%s @ %.4f" % [action, time])
			_check(secondary.visible == (index == 3 and time >= 8.0 / 30.0 and time < 16.0 / 30.0), "第四段第二次特效独立运行")
	visual.play_action(&"attack_4", true)
	visual.advance_animation(0.35)
	var second := secondary.get_animation_state().get_track(0)
	_check(second != null and second.get_animation().get_name() == "attack4" and absf(second.get_track_time() - (0.35 - 8.0 / 30.0)) < 0.001, "低帧率跨越第四段两次触发，第二次从正确局部时间播放")
	visual.advance_animation(0.2)
	_check(not primary.visible and not secondary.visible, "两次特效都在素材结束后清理")
#endregion
#region 左右镜像、原始偏移与实例隔离
func _verify_facing_and_isolation() -> void:
	visual.play_action(&"attack_4", true)
	visual.advance_animation(0.3)
	_check(secondary.position.is_equal_approx(Vector2(-17, -4)) and secondary.scale.is_equal_approx(Vector2(-1, 1)), "保留原版第二击偏移和负显示缩放")
	visual.set_facing(1)
	_check(secondary.global_position.is_equal_approx(visual.global_position + Vector2(-34, -8)) and secondary.global_transform.x.x < 0, "右朝向的偏移与反向特效")
	var time := secondary.get_animation_state().get_track(0).get_track_time()
	visual.set_facing(-1)
	_check(secondary.global_position.is_equal_approx(visual.global_position + Vector2(34, -8)) and secondary.global_transform.x.x > 0, "左朝向同时镜像偏移和反向特效")
	_check(is_equal_approx(secondary.get_animation_state().get_track(0).get_track_time(), time), "转向不重置特效进度")
	var other := (load("res://data/animation/sunwukong_visual.tscn") as PackedScene).instantiate() as SpineAnimationAdapter
	add_child(other)
	other.play_action(&"idle", true)
	_check(not (other.get_node("AttackEffects/Secondary") as SpineSprite).visible and secondary.visible, "共享骨架资源的两个角色拥有独立特效状态")
	_check(other.get_node("AttackEffects").scale.x > 0 and visual.get_node("AttackEffects").scale.x < 0, "实例朝向互不影响")
	other.free()
	visual.set_facing(1)
#endregion
#region 动作中断和重新释放
func _verify_cancel_and_restart() -> void:
	for action in [&"idle", &"move", &"run", &"jump", &"jump_2", &"fall", &"land", &"hurt", &"death"]:
		visual.play_action(&"attack_4", true)
		visual.advance_animation(0.3)
		visual.play_action(action, true)
		_check(not primary.visible and not secondary.visible and secondary.get_animation_state().get_track(0) == null, "切换到 %s 清理旧攻击特效" % action)
	visual.play_action(&"attack_1", true)
	visual.advance_animation(0.2)
	visual.play_action(&"attack_1", true)
	_check(not primary.visible and primary.get_animation_state().get_track(0) == null, "重放同一攻击从前摇开始")
	visual.advance_animation(0.15)
	_check(primary.visible and absf(primary.get_animation_state().get_track(0).get_track_time() - (0.15 - 4.0 / 30.0)) < 0.001, "重放不会继承旧特效进度")
#endregion
#region 真实战斗暂停、慢动作、受击停顿和跳取消
func _verify_battle_clock() -> void:
	var demo := (load("res://examples/original_damage_demo.tscn") as PackedScene).instantiate()
	demo.enable_player_controls = false
	add_child(demo)
	demo.set_physics_process(false)
	var session := demo.session as BattleSession
	session.set_physics_process(false)
	for tick in range(8):
		await get_tree().physics_frame
		session.advance_physics(1.0 / 60.0)
	var actor := demo.player as BattleEntity2D
	_check(actor.request_attack(), "真实 GAS 普攻激活")
	session.advance_physics(0.16)
	var effect := actor.animation.get_node("AttackEffects/Primary") as SpineSprite
	_check(effect.visible, "伤害样例中实际角色播放攻击特效")
	var entry := effect.get_animation_state().get_track(0)
	var before := entry.get_track_time()
	session.set_paused(true)
	session.advance_physics(0.1)
	_check(is_equal_approx(entry.get_track_time(), before), "暂停冻结攻击特效")
	session.set_paused(false)
	# 普攻命中本身会请求受击停顿；先耗尽它，再单独验证慢动作。
	session.advance_physics(session.clock.hit_stop_remaining)
	session.set_time_scale(0.5)
	session.advance_physics(0.04)
	entry = effect.get_animation_state().get_track(0)
	_check(absf(entry.get_track_time() - before - 0.02) < 0.001, "特效与战斗时钟同步慢动作")
	before = entry.get_track_time()
	session.request_hit_stop(0.1)
	session.advance_physics(0.04)
	_check(is_equal_approx(entry.get_track_time(), before), "受击停顿冻结攻击特效")
	session.advance_physics(0.2)
	session.set_time_scale(1.0)
	_check(actor.try_jump(), "攻击中通过动作状态入口跳取消")
	session.advance_physics(0.01)
	_check(not effect.visible and effect.get_animation_state().get_track(0) == null, "真实 GAS 取消后旧特效清理")
	session.clear_battle()
	demo.queue_free()
	await get_tree().process_frame
	await _verify_real_combo_attachments()

func _verify_real_combo_attachments() -> void:
	for facing in [1, -1]:
		var demo := (load("res://examples/original_damage_demo.tscn") as PackedScene).instantiate()
		demo.enable_player_controls = false
		add_child(demo)
		demo.set_physics_process(false)
		var session := demo.session as BattleSession
		session.set_physics_process(false)
		for tick in range(8):
			await get_tree().physics_frame
			session.advance_physics(1.0 / 60.0)
		var actor := demo.player as BattleEntity2D
		actor.animation.set_facing(facing)
		demo.place_near()
		_check(actor.request_attack(), "真实五连击开始")
		var queued: int = -1
		var checked := {}
		var sample_times := {&"attack_1": 0.2, &"attack_2": 0.2, &"attack_3": 0.16, &"attack_4": 0.1, &"attack_5": 0.27}
		for tick in range(250):
			if actor.combo.is_active() and actor.combo.index != queued:
				queued = actor.combo.index
				actor.request_attack()
			session.advance_physics(1.0 / 60.0)
			var action := actor.animation.get_current_action()
			var time := actor.animation.get_playback_time()
			if sample_times.has(action) and time >= sample_times[action] and not checked.has(action):
				checked[action] = true
				_check_effect_pose(actor.animation as SpineAnimationAdapter, action, time, "真实连招朝向%d / %s" % [facing, action])
			if action == &"attack_4" and time >= 0.35 and not checked.has(&"attack_4_second"):
				checked[&"attack_4_second"] = true
				_check_effect_pose(actor.animation as SpineAnimationAdapter, action, time, "第四段第二击")
			if checked.size() == 6 and not actor.combo.is_active():
				break
		_check(checked.size() == 6, "左右朝向真实连招全部六次特效都完成附件验收")
		_check_effect_pose(actor.animation as SpineAnimationAdapter, &"idle", 0.0, "连招结束")
		session.clear_battle()
		demo.queue_free()
		await get_tree().process_frame
#endregion
