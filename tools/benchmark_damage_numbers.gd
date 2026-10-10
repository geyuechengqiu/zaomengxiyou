extends "res://tests/fixtures/original_damage_demo.gd"
#region 真实跳字压力测试配置
const STYLES := ["normal", "critical", "true", "true_critical", "player", "dodge", "normal_double", "critical_double", "special", "kill", "heal"]
var report_name: String = "current"
var feedback: BattleCombatFeedback2D
var check_order_only: bool = false
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.cleanup-backup"))
	super._ready()
	session.set_physics_process(false)
	set_process(false)
	operations.enabled = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for arg in OS.get_cmdline_user_args():
		if arg == "--check-order-only":
			check_order_only = true
		if arg.begins_with("--report-name="):
			report_name = arg.get_slice("=", 1).validate_filename()
	feedback = dummies[1].feedback
	await _idle_frames(12)
	if check_order_only:
		var passed := await _verify_reuse_draw_order()
		get_tree().quit(0 if passed else 1)
		return
	var results: Array[Dictionary] = []
	for count in [100, 500, 1000, 2000, 5000]:
		results.append(await _burst(count, false))
		results.append(await _burst(count, true))
		print("PROGRESS damage stress ", report_name, ": ", JSON.stringify(results[-2]), " warm ", JSON.stringify(results[-1]))
		await _idle_frames(4)
	results.append(await _stream(20, 240))
	results.append(await _stream(60, 240))
	if not await _verify_reuse_draw_order():
		get_tree().quit(1)
		return
	var report := {"engine": Engine.get_version_info().string, "gpu": RenderingServer.get_video_adapter_name(), "cpu": OS.get_processor_name(), "viewport": get_viewport_rect().size, "vsync": "disabled", "method": "actual damage_number PackedScene via CombatFeedback, mixed original styles and 1-5 digits, GPU-rendered; 48 updates/burst, delta=1/120; stream delta=1/60; render_frame=update to frame_post_draw (not entire frame), full_frame=update through next process_frame; spawn reported separately", "results": results}
	var file := FileAccess.open("res://.cleanup-backup/damage-number-stress-" + report_name + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("PASS actual GPU damage-number stress ", report_name)
	get_tree().quit()
#endregion
#region 生成、更新、绘制与突发帧计时
func _spawn(index: int) -> void:
	var x := 35.0 + float((index * 53) % 860)
	var y := 170.0 + float((index * 29) % 210)
	feedback._spawn_number(1 + (index * 7919) % 99999, STYLES[index % STYLES.size()], Vector2(x, y))

func _advance(delta: float) -> void:
	if feedback.number_rows.has_method(&"advance_numbers"):
		feedback.number_rows.advance_numbers(delta)
	else:
		for row: BattleDamageNumber2D in feedback.number_rows.get_children():
			row.advance_number(delta)

func _clear() -> void:
	# 通过正常动画到期清理，优化后的对象池也可完整回收。
	_advance(1.0)

func _idle_frames(count: int) -> void:
	for frame in range(count):
		await get_tree().process_frame

func _burst(count: int, warm: bool) -> Dictionary:
	_clear()
	await _idle_frames(2)
	var memory_before := OS.get_static_memory_usage()
	var started := Time.get_ticks_usec()
	for index in range(count):
		_spawn(index)
	var spawn_us := Time.get_ticks_usec() - started
	var memory_bytes := OS.get_static_memory_usage() - memory_before
	var frames: Array[float] = []
	var full_frames: Array[float] = []
	var updates: Array[float] = []
	var calls: Array[float] = []
	for frame in range(48):
		var frame_start := Time.get_ticks_usec()
		var update_start := Time.get_ticks_usec()
		_advance(1.0 / 120.0)
		updates.append((Time.get_ticks_usec() - update_start) / 1000.0)
		await RenderingServer.frame_post_draw
		frames.append((Time.get_ticks_usec() - frame_start) / 1000.0)
		calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		if frame == 23 and count == 100:
			get_viewport().get_texture().get_image().save_png("res://.cleanup-backup/damage-number-stress-" + report_name + ("-warm.png" if warm else ".png"))
		await get_tree().process_frame
		full_frames.append((Time.get_ticks_usec() - frame_start) / 1000.0)
	_clear()
	await _idle_frames(2)
	return {"mode": "burst_warm" if warm else "burst_first", "live": count, "spawn_ms": spawn_us / 1000.0, "memory_delta_bytes": memory_bytes, "update_p50_ms": _percentile(updates, 0.5), "update_p95_ms": _percentile(updates, 0.95), "render_frame_p50_ms": _percentile(frames, 0.5), "render_frame_p95_ms": _percentile(frames, 0.95), "draw_calls_p50": _percentile(calls, 0.5), "full_frame_p50_ms": _percentile(full_frames, 0.5), "full_frame_p95_ms": _percentile(full_frames, 0.95)}

func _stream(per_frame: int, frames: int) -> Dictionary:
	_clear()
	await _idle_frames(2)
	var timings: Array[float] = []
	var full_frames: Array[float] = []
	var updates: Array[float] = []
	var peak_live := 0
	for frame in range(frames):
		var frame_start := Time.get_ticks_usec()
		var update_start := Time.get_ticks_usec()
		for index in range(per_frame):
			_spawn(frame * per_frame + index)
		_advance(1.0 / 60.0)
		peak_live = maxi(peak_live, feedback.number_rows.get_active_count())
		updates.append((Time.get_ticks_usec() - update_start) / 1000.0)
		await RenderingServer.frame_post_draw
		timings.append((Time.get_ticks_usec() - frame_start) / 1000.0)
		await get_tree().process_frame
		full_frames.append((Time.get_ticks_usec() - frame_start) / 1000.0)
	_clear()
	await _idle_frames(2)
	var result := {"mode": "stream", "new_per_second": per_frame * 60, "frames": frames, "peak_live": peak_live, "spawn_update_p50_ms": _percentile(updates, 0.5), "spawn_update_p95_ms": _percentile(updates, 0.95), "render_frame_p50_ms": _percentile(timings, 0.5), "render_frame_p95_ms": _percentile(timings, 0.95), "full_frame_p50_ms": _percentile(full_frames, 0.5), "full_frame_p95_ms": _percentile(full_frames, 0.95)}
	print("PROGRESS damage stream ", report_name, ": ", JSON.stringify(result))
	return result

func _verify_reuse_draw_order() -> bool:
	var layer := feedback.number_rows
	layer.clear_numbers()
	await _idle_frames(2)
	var at := Vector2(470, 300)
	var first := layer.spawn_number(feedback.number_scene, 888, "normal", at)
	var second := layer.spawn_number(feedback.number_scene, 888, "normal", at)
	second.modulate = Color.GREEN
	first.advance_number(1.0)
	var reused := layer.spawn_number(feedback.number_scene, 888, "normal", at)
	reused.modulate = Color.RED
	# 新增第三个节点触发Godot默认Canvas排序；检查恢复后依然按出生顺序。
	var third := layer.spawn_number(feedback.number_scene, 888, "normal", at + Vector2(10, 0))
	third.modulate = Color.BLUE
	await _idle_frames(3)
	await RenderingServer.frame_post_draw
	var before := get_viewport().get_texture().get_image()
	# 暂停自定义排序，用引擎真实子节点顺序构造独立参考图。
	RenderingServer.frame_pre_draw.disconnect(layer._refresh_render_order)
	for row in layer.get_active_numbers():
		layer.move_child(row, -1)
	await _idle_frames(3)
	await RenderingServer.frame_post_draw
	var after := get_viewport().get_texture().get_image()
	RenderingServer.frame_pre_draw.connect(layer._refresh_render_order)
	if before.get_data() != after.get_data():
		push_error("复用与新节点混合的GPU绘制顺序与出生顺序不一致")
		return false
	print("PASS GPU reused/new number overlap draw order")
	layer.clear_numbers()
	return true

func _percentile(values: Array[float], fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, int(ceil(fraction * sorted.size())) - 1)]
#endregion
