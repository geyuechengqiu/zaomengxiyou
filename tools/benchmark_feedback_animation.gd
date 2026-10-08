extends Node
#region 当前真实跳字的主线程微基准入口
const COUNT: int = 1000
const RUNS: int = 5
const SCENE: PackedScene = preload("res://data/effects/damage_number.tscn")
var layer: BattleDamageNumberLayer2D
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.cleanup-backup"))
	layer = BattleDamageNumberLayer2D.new()
	layer.number_scene = SCENE
	layer.prewarm_count = COUNT
	add_child(layer)
	var samples: Array[Dictionary] = []
	for run in range(RUNS):
		samples.append(_bench(COUNT))
		await get_tree().process_frame
	var report := {"engine": Engine.get_version_info().string, "count": COUNT, "runs": RUNS, "updates": 54, "delta": 1.0 / 60.0, "method": "actual pooled damage_number PackedScene, shared atlas and static Tween curve; headless CPU only, no GPU drawing; use benchmark_damage_numbers.tscn for render/full-frame results", "samples": samples}
	var file := FileAccess.open("res://.cleanup-backup/feedback-tween-benchmark.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n")
	print("PASS feedback Tween benchmark: ", JSON.stringify(report))
	get_tree().quit()
#endregion
#region 真实场景复用与战斗时钟推进
func _bench(count: int) -> Dictionary:
	var memory_before := OS.get_static_memory_usage()
	var started := Time.get_ticks_usec()
	for index in range(count):
		layer.spawn_number(SCENE, index, "critical" if index % 2 else "normal", Vector2.ZERO)
	var spawn_us := Time.get_ticks_usec() - started
	var memory_bytes := OS.get_static_memory_usage() - memory_before
	started = Time.get_ticks_usec()
	for frame in range(54):
		layer.advance_numbers(1.0 / 60.0)
	return {"spawn_us": spawn_us, "advance_us": Time.get_ticks_usec() - started, "memory_bytes": memory_bytes, "pool": layer.get_pool_stats()}
#endregion
