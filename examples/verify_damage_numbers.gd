extends Node
#region 真实场景、结算与原版跳字验收
var demo: Node2D
var checks: int = 0
var failures: Array[String] = []
var hits: Array[Dictionary] = []
var starts: Array[int] = []

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _ready() -> void:
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	await _verify_assets()
	await _verify_samples()
	await _verify_combo(1)
	await _verify_combo(-1)
	await _verify_lifecycle()
	await _verify_window_scaling()
	CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	demo.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS original damage numbers: %d checks; original textures, screen-space independent rows, ordinary/crit/true/dodge/shield, pause, RNG isolation, overkill and five combo steps/six hits in both directions" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _fresh() -> void:
	if is_instance_valid(demo):
		demo.free()
	demo = load("res://examples/original_damage_demo.tscn").instantiate()
	demo.enable_player_controls = false
	add_child(demo)
	demo.session.set_physics_process(false)
	await _step(40)
	demo.place_near()
	hits.clear()
	starts.clear()

func _step(count: int, delta: float = 1.0 / 60.0) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		demo.session.advance_physics(delta)

func _on_event(id: String, payload: Array) -> void:
	if not is_instance_valid(demo) or not is_instance_valid(demo.session) or not is_instance_valid(demo.player) or payload.size() != 1 or payload[0].get("battle_id") != demo.session.battle_id or payload[0].get("source_entity_id") != demo.player.entity_id:
		return
	if id == "battle.attack.hit":
		hits.append(payload[0].duplicate())
	elif id == "battle.combo.started":
		starts.append(payload[0].combo_step)
#endregion
#region 素材、原版动画与八个结算样例
func _verify_assets() -> void:
	var library: BattleDamageNumberLibrary = load("res://data/effects/damage_number_textures.tres")
	var count := 0
	for group in library.groups.values():
		count += group.size()
	_check(library.groups.size() == 14 and count == 115, "导出14组115张原版贴图，暴击别名不当作动画")
	for group in ["bleedNumber", "baojiNumber", "real_bleedNumber", "real_baojiNumber", "playerBleedNumber"]:
		_check(library.get_group(group).size() == 10, "每组保留0至9的原数字贴图：" + group)
	var scene := load("res://data/effects/damage_number.tscn") as PackedScene
	var number := scene.instantiate() as BattleDamageNumber2D
	add_child(number)
	number.advance_number(0.2)
	var glyphs := number.get_node("Glyphs") as BattleDamageNumberGlyphs
	_check(glyphs.position.is_equal_approx(Vector2(-20, -100)) and glyphs.scale.is_equal_approx(Vector2.ONE), "0.2秒上飘100像素、左移20像素，从0.8放大到1")
	number.advance_number(0.1)
	_check(is_equal_approx(glyphs.modulate.a, 1.0) and is_zero_approx(glyphs.rotation), "0.3秒前保持不淡出，原版无旋转")
	number.advance_number(0.6)
	_check(number.finished and not number.visible and glyphs.position.is_equal_approx(Vector2(0, -60)) and is_equal_approx(glyphs.modulate.a, 0.2), "跨完整动画后回落40像素、淡到0.2并清理")
	await get_tree().process_frame

func _verify_samples() -> void:
	for sample in range(8):
		await _fresh()
		demo.set_sample(sample)
		demo.player.request_attack()
		await _step(8)
		var rows: Array[BattleDamageNumber2D] = demo.dummies[1].feedback.number_rows.get_active_numbers()
		var expected_values := [[80], [160], [40], [87], [40, 50], [30], [0], []]
		var expected_styles := [["normal"], ["critical"], ["normal"], ["normal"], ["normal", "true"], ["normal"], ["dodge"], []]
		_check(rows.map(func(row): return row.number) == expected_values[sample], "真实命中跳字整数分量：%s" % demo.SAMPLES[sample])
		_check(rows.map(func(row): return row.style) == expected_styles[sample], "真实命中跳字类别：%s" % demo.SAMPLES[sample])
		var target: BattleEntity2D = demo.dummies[1]
		var origin := target.get_canvas_transform() * (target.global_position + Vector2(0, -120)) + Vector2(0, -60)
		if sample == 0:
			_check(rows[0].position.is_equal_approx(origin), "普通伤害主分支使用固定出生点，不擅自添加随机")
		if sample == 6:
			var offset: Vector2 = rows[0].position - origin
			_check(offset.x >= 0.0 and offset.x <= 20.0 and offset.y >= -20.0 and offset.y <= 0.0, "闪避分支按原式随机出生位置")
		if sample == 4:
			var normal: BattleDamageNumber2D = rows[0]
			var real: BattleDamageNumber2D = rows[1]
			var offset := real.position - normal.position
			_check(absf(offset.x) <= 60.0 and offset.y >= -40.0 and offset.y <= -10.0, "真实伤害追加屏幕随机偏移而非替换普通跳字")
		if sample == 5:
			_check(demo.dummies[1].feedback.get_node("DamageLabel").visible and hits[0].shield_absorbed == 50.0, "盾后数字30，同时保留护盾50说明")
#endregion
#region 窗口拉伸、镜头与反馈层坐标回归
func _verify_window_scaling() -> void:
	var window := get_window()
	var original_size := window.size
	var original_scale := window.content_scale_size
	var original_mode := window.content_scale_mode
	window.content_scale_size = Vector2i(940, 590)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for size in [Vector2i(940, 590), Vector2i(1880, 1180), Vector2i(1280, 720), Vector2i(640, 480)]:
		window.size = size
		await _fresh()
		var target: BattleEntity2D = demo.dummies[1]
		var actor_point := target.global_position + Vector2(0, -120)
		var expected := target.get_canvas_transform() * actor_point + Vector2(0, -60)
		_check(demo.player.request_attack(), "窗口%s可发起真实普攻" % str(size))
		await _step(8)
		var row := target.feedback.number_rows.get_active_numbers()[0] as BattleDamageNumber2D
		var logical_point := row.get_global_transform_with_canvas().origin
		_check(logical_point.is_equal_approx(expected), "窗口%s：跳字出生在逻辑视口位置，只拉伸一次" % str(size))
		_check(get_viewport().get_visible_rect().has_point(logical_point), "窗口%s：实际命中数字在画面内" % str(size))
		if size == Vector2i(1880, 1180):
			_check(not get_viewport().get_final_transform().is_equal_approx(Transform2D.IDENTITY), "确实启用窗口拉伸，覆盖曾移出画面的2倍窗口")
		# 自定义反馈 CanvasLayer 与 Rows 变换时也按相同目标点显示。
		var rows: BattleDamageNumberLayer2D = target.feedback.number_rows
		var layer := rows.get_parent() as CanvasLayer
		layer.offset = Vector2(31, 17)
		rows.position = Vector2(13, -9)
		rows.scale = Vector2(1.2, 0.8)
		target.feedback._show_original_numbers({"normal_damage": 10.0})
		var shifted := rows.get_active_numbers()[-1] as BattleDamageNumber2D
		_check(shifted.get_global_transform_with_canvas().origin.is_equal_approx(expected), "窗口%s：反馈层偏移和缩放不影响出生点" % str(size))
	window.size = original_size
	window.content_scale_size = original_scale
	window.content_scale_mode = original_mode
#endregion
#region 五段实战、翻转与生命周期
func _verify_combo(facing: int) -> void:
	await _fresh()
	demo.player.animation.set_facing(facing)
	demo.place_near()
	_check(demo.player.combo.definition.steps.size() == 5 and demo.player.abilities.has_ability(&"sunwukong_run_attack") and demo.player.abilities.has_ability(&"sunwukong_jump_attack"), "场景预置五连击与跑攻、跳攻GAS技能")
	_check(demo.player.request_attack(), "发起五连击")
	for duration in [10, 10, 12, 18]:
		_check(demo.player.request_attack(), "同一普攻入口预约下一段")
		await _step(duration * 2)
	await _step(12)
	var target: BattleEntity2D = demo.dummies[1 if facing > 0 else 0]
	_check(target.feedback.number_rows.get_active_count() > 1, "第五段命中时第四段旧跳字仍存在，不被新跳字覆盖")
	await _step(28)
	_check(starts == [1, 2, 3, 4, 5], "五段顺序完整，朝向%d" % facing)
	var target_hits := hits.filter(func(hit): return hit.target_entity_id == target.entity_id)
	_check(target_hits.map(func(hit): return hit.combo_step) == [1, 2, 3, 4, 4, 5], "正面目标第四段两次命中，总计六次，朝向%d" % facing)
	_check(target_hits.map(func(hit): return int(hit.calculated_damage)) == [80, 80, 96, 36, 36, 160], "保留五段各自原版倍率")
	_check(not demo.player.combo.is_active() and demo.player.action_state.current == BattleActionState2D.State.IDLE, "五连击结束回待机")
	for row in target.feedback.number_rows.get_active_numbers():
		_check(row.get_node("Glyphs").scale.x > 0.0, "角色镜像后数字仍正向显示")
	await _step(60)
	_check(target.feedback.number_rows.get_active_count() == 0, "动画到期清理所有连击数字")

func _verify_lifecycle() -> void:
	await _fresh()
	demo.set_sample(4)
	demo.player.request_attack()
	await _step(8)
	var row := demo.dummies[1].feedback.number_rows.get_active_numbers()[0] as BattleDamageNumber2D
	var position := row.position
	var elapsed := row.elapsed
	demo.session.set_paused(true)
	await _step(10)
	_check(row.elapsed == elapsed, "暂停冻结跳字时钟")
	demo.session.set_paused(false)
	demo.dummies[1].position.x += 100.0
	await _step(1)
	_check(row.position == position and row.elapsed > elapsed, "数字固定在命中时屏幕位置，目标移动不拖动旧数字")
	demo.session.random.random_float(&"combat")
	var combat_state: int = demo.session.random.snapshot().states[&"combat"]
	demo.dummies[1].feedback._show_original_numbers({"normal_damage": 10.0, "true_damage": 5.0, "is_crit": true})
	_check(demo.session.random.snapshot().states[&"combat"] == combat_state, "跳字随机流不消耗战斗随机序列")
	var rows: Array[BattleDamageNumber2D] = demo.dummies[1].feedback.number_rows.get_active_numbers()
	_check(rows[-1].style == "true_critical" and rows[-2].style == "critical", "真实暴击和普通暴击使用各自原素材")
	await _fresh()
	var target: BattleEntity2D = demo.dummies[1]
	target.receive_damage(495.0)
	_check(target.feedback.number_rows.get_active_count() == 1 and target.feedback.number_rows.get_active_numbers()[0].number == 495, "直接伤害也由公共结算事件生成一次跳字")
	# 隔离下一次过量攻击的展示断言，先清理用于准备5HP的直接伤害数字。
	target.feedback.number_rows.clear_numbers()
	demo.player.request_attack()
	await _step(8)
	_check(hits[0].actual_hp_loss == 5.0 and target.feedback.number_rows.get_active_numbers()[0].number == 80, "过量伤害跳字显示原结算80，面板实际扣血5")
	await _step(60)
	_check(target.feedback.number_rows.get_active_count() == 0, "死亡目标的跳字仍正确到期")
#endregion
