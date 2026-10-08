extends Node
#region 验收夹具与入口
var demo: Node2D
var session: BattleSession
var target: BattleEntity2D
var failures: Array[String] = []
var checks: int = 0
func _ready() -> void:
	demo = load("res://examples/original_damage_demo.tscn").instantiate()
	demo.enable_player_controls = false
	add_child(demo)
	session = demo.session
	session.set_physics_process(false)
	target = demo.dummies[1]
	await _step(8)
	await _verify_actual_health()
	_verify_source_rules()
	await _verify_continuous_numbers()
	session.clear_battle()
	demo.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS original feedback: %d checks; original bar textures/mask, reveal/hide/trail, minimum HP, team/permanent/death, facing, combat clock and exact continuous Tween trajectory" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)
func _step(count: int = 1, delta: float = 1.0 / 60.0) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		session.advance_physics(delta)
#endregion
#region 真实生命通知与战斗时间
func _verify_actual_health() -> void:
	var bar: BattleMonsterHealthBar2D = target.feedback.get_node("HealthBar")
	_check(not bar.visible and not target.feedback.get_node("HealthLabel").visible, "怪物出生隐藏血条，原版无生命数值文字")
	_check(not demo.player.feedback.get_node("HealthBar").enabled, "悟空默认不显示怪物头顶血条，生命面板仍独立")
	_check((bar.get_node("Background") as Sprite2D).texture.get_size() == Vector2(62, 6) and bar.trail.texture.get_size() == Vector2(60, 4), "使用原版62×6背景和60×4生命贴图")
	_check(bar.scale == Vector2(2, 2) and bar.position == Vector2(0, -200), "原版默认偏移(0,-100)按2倍战斗坐标换算")
	target.receive_damage(100.0)
	_check(bar.visible and is_equal_approx(bar.mask_ratio, 0.8) and bar.trail.scale.x == 1.0, "扣血立即改变前景遮罩，残血层保持上一生命比例")
	await _step(18)
	_check(is_equal_approx(bar.trail.scale.x, 0.85), "0.6秒Quad.easeOut残血补间中点与原版一致")
	var timer_before := bar.hide_remaining
	var trail_before := bar.trail.scale.x
	session.set_paused(true)
	await _step(12)
	_check(bar.hide_remaining == timer_before and bar.trail.scale.x == trail_before, "暂停冻结隐藏计时和残血补间")
	session.set_paused(false)
	session.request_hit_stop(0.05)
	await _step(2)
	_check(bar.hide_remaining == timer_before and bar.trail.scale.x == trail_before, "受击停顿冻结血条倒计时和残血补间")
	await _step(1)
	session.set_time_scale(0.5)
	await _step(12)
	_check(is_equal_approx(timer_before - bar.hide_remaining, 0.1), "慢动作统一影响血条补间与隐藏计时")
	session.set_time_scale(1.0)
	target.receive_damage(50.0)
	_check(is_equal_approx(bar.mask_ratio, 0.7) and bar.hide_remaining == 2.0, "再次扣血重新开始两秒隐藏计时")
	await _step(36)
	_check(is_equal_approx(bar.trail.scale.x, 0.7), "连续扣血残血层收敛到最新比例")
	await _step(83)
	_check(bar.visible, "两秒截止前仍显示")
	await _step(2)
	_check(not bar.visible, "两秒后隐藏怪物血条")
	(target.attributes.get_vital(&"health") as HealthVital).heal(25.0)
	_check(bar.visible and is_equal_approx(bar.mask_ratio, 0.75), "治疗通过统一生命通知刷新比例和显示")
	bar.source_offset = Vector2(12, -110)
	target.animation.set_facing(-1)
	await _step()
	_check(bar.position == Vector2(-24, -220) and bar.scale.x > 0.0, "转向只镜像偏移X，血条不反向")
	target.receive_damage(1000.0)
	_check(not bar.visible and is_zero_approx(bar.mask_ratio), "死亡立即隐藏，取消残血补间")
#endregion
#region 原版配置、低血量、同值提前返回和实例隔离
func _verify_source_rules() -> void:
	var scene: PackedScene = load("res://data/effects/monster_health_bar.tscn")
	var bar: BattleMonsterHealthBar2D = scene.instantiate()
	add_child(bar)
	bar.configure(true, false, false, 100, 100)
	bar.set_health(1, 100)
	_check(is_equal_approx(bar.mask_ratio, 0.04) and is_equal_approx(bar.mask.size.x, 2.52), "非零低血量至少4%，精确保留63像素宽原版遮罩")
	bar.set_health(60, 100)
	bar.advance_bar(0.5, 1)
	var timer := bar.hide_remaining
	bar.set_health(60, 100)
	_check(bar.hide_remaining == timer and bar.visible, "相同比例先显示后提前返回，不刷新定时器")
	bar.advance_bar(2.0, 1)
	bar.show_health()
	_check(bar.visible and bar.hide_remaining < 0.0, "保留原版同值显现且无新隐藏定时器的边界")
	bar.configure(true, true, false, 100, 100)
	_check(bar.visible, "alwaysShowHP出生就显示")
	bar.set_health(50, 100)
	bar.advance_bar(3.0, 1)
	_check(bar.visible, "常显血条不被两秒定时器隐藏")
	bar.configure(true, false, true, 100, 100)
	bar.advance_bar(1.0, 1)
	bar.set_health(50, 100)
	bar.advance_bar(3.0, 1)
	_check(bar.visible and bar.hide_remaining < 0.0, "队友每秒刷新，血量变化不创建两秒隐藏计时")
	bar.configure(false, false, false, 100, 100)
	bar.set_health(50, 100)
	_check(not bar.visible, "showHP关闭时不显示")
	_check(not demo.dummies[0].feedback.get_node("HealthBar").visible, "另一个同定义木桩保持自己的可见状态")
	bar.queue_free()
#endregion
#region 连续原版曲线与低帧率跨段清理
func _verify_continuous_numbers() -> void:
	var scene: PackedScene = load("res://data/effects/damage_number.tscn")
	var row: BattleDamageNumber2D = scene.instantiate()
	add_child(row)
	_check(row.get_node_or_null("AnimationPlayer") == null, "运行时跳字不包含AnimationPlayer节点")
	var previous := 0.0
	for time in [0.0125, 0.075, 0.17, 0.201, 0.25, 0.305, 0.475, 0.89]:
		row.advance_number(time - previous)
		previous = time
		var q: float
		var expected: Vector2
		var scale_value: float = 1.0
		var alpha: float = 1.0
		if time < 0.2:
			q = 1.0 - pow(1.0 - time / 0.2, 2)
			expected = Vector2(-20, -100) * q
			scale_value = 0.8 + 0.2 * q
		elif time < 0.3:
			expected = Vector2(-20, -100)
		else:
			q = 1.0 - pow(1.0 - (time - 0.3) / 0.6, 2)
			expected = Vector2(-20, -100) + Vector2(20, 40) * q
			alpha = 1.0 - 0.8 * q
		_check(row.glyphs.position.is_equal_approx(expected) and is_equal_approx(row.glyphs.scale.x, scale_value) and is_equal_approx(row.glyphs.modulate.a, alpha), "非30FPS采样点%.4f秒与原版连续Quad.easeOut一致" % time)
	var frozen := row.glyphs.position
	await get_tree().process_frame
	await get_tree().process_frame
	_check(row.glyphs.position == frozen, "Tween不自行吃SceneTree帧时间")
	row.advance_number(0.0)
	_check(row.glyphs.position == frozen, "零战斗delta不推进跳字")
	row.advance_number(0.5)
	_check(row.finished and not row.visible and row.glyphs.position == Vector2(0, -60), "低帧率跨结束时间正常落在末帧并清理")
	await get_tree().process_frame
#endregion
