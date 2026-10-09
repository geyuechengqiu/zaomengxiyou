extends Resource
class_name BattleLevelDefinition
#region 共享定义
@export var definition_id: StringName = &""
@export var display_name: String = ""
@export var scene: PackedScene
@export var spawns: Array[BattleSpawnDefinition] = []
@export var regions: Array[BattleRegionDefinition] = []
@export var waves: Array[BattleWaveDefinition] = []
@export var spawn_plans: Array[BattleSpawnPlanDefinition] = []
@export var condition_ids: Array[StringName] = []
@export var required_conditions: Array[StringName] = []
@export var required_boss_plan_ids: Array[StringName] = []
#endregion
#region 数据图验证：拒绝缺失引用、重复归属和循环依赖
func get_progression_error() -> String:
	if regions.is_empty():
		return "缺少区域定义" if not waves.is_empty() or not spawn_plans.is_empty() else ""
	var seen_conditions := {}
	for id in condition_ids:
		if id.is_empty() or seen_conditions.has(id): return "条件ID为空或重复"
		seen_conditions[id] = true
	var region_map := {}
	var wave_map := {}
	var plan_map := {}
	for region in regions:
		if region == null or region.region_id.is_empty() or region_map.has(region.region_id): return "区域ID为空或重复"
		for rect in [region.bounds, region.entry_rect, region.exit_rect]:
			if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x <= 0 or rect.size.y <= 0: return "区域矩形无效"
		region_map[region.region_id] = region
		if not is_finite(region.camera_transition_margin) or region.camera_transition_margin < 0: return "镜头切区提前范围无效"
	for wave in waves:
		if wave == null or wave.wave_id.is_empty() or wave_map.has(wave.wave_id) or not region_map.has(wave.region_id): return "波次ID或区域归属无效"
		wave_map[wave.wave_id] = wave
	for plan in spawn_plans:
		if plan == null or plan.plan_id.is_empty() or plan_map.has(plan.plan_id) or plan.spawn_point_id.is_empty() or plan.monster_ids.is_empty(): return "出生计划ID、出生点或怪物列表无效"
		if not is_finite(plan.delay_seconds) or plan.delay_seconds < 0 or not is_finite(plan.interval_seconds) or plan.interval_seconds < 0 or plan.facing not in [-1, 1]: return "出生计划时间或朝向无效"
		plan_map[plan.plan_id] = plan
	var seen_waves := {}
	var seen_plans := {}
	var edges := {}
	for region in regions:
		if region.wave_ids.is_empty(): return "区域没有波次"
		if not _conditions_valid(region.required_conditions): return "区域条件未声明"
		for id in region.wave_ids:
			if not wave_map.has(id) or seen_waves.has(id) or wave_map[id].region_id != region.region_id: return "区域波次引用错误或重复归属"
			seen_waves[id] = true
	for wave in waves:
		if wave.plan_ids.is_empty() or not _conditions_valid(wave.required_conditions): return "波次计划或条件无效"
		edges[wave.wave_id] = wave.after_wave_ids
		for id in wave.after_wave_ids:
			if not wave_map.has(id): return "前置波次不存在"
		for id in wave.plan_ids:
			if not plan_map.has(id) or seen_plans.has(id): return "出生计划引用错误或重复归属"
			seen_plans[id] = wave.wave_id
	if seen_waves.size() != waves.size() or seen_plans.size() != spawn_plans.size(): return "波次或计划没有区域归属"
	if _has_cycle(edges): return "波次依赖存在循环"
	edges.clear()
	for plan in spawn_plans:
		if not _conditions_valid(plan.required_conditions): return "出生计划条件未声明"
		var dependencies: Array = []
		dependencies.append_array(plan.after_created_plan_ids)
		dependencies.append_array(plan.after_dead_plan_ids)
		edges[plan.plan_id] = dependencies
		for id in dependencies:
			if not plan_map.has(id): return "前置出生点不存在"
	if _has_cycle(edges): return "出生计划依赖存在循环"
	# 将波次启动与计划完成纳入同一依赖图，捕获跨类型的等待死锁。
	edges.clear()
	var region_order := {}
	for index in range(regions.size()): region_order[regions[index].region_id] = index
	for wave in waves:
		var dependencies: Array = []
		for id in wave.after_wave_ids:
			if region_order[wave_map[id].region_id] > region_order[wave.region_id]: return "波次不能依赖后续区域"
			dependencies.append("w:" + String(id))
		edges["w:" + String(wave.wave_id)] = dependencies
	for plan in spawn_plans:
		var dependencies: Array = ["w:" + String(seen_plans[plan.plan_id])]
		for id in plan.after_created_plan_ids + plan.after_dead_plan_ids:
			if region_order[wave_map[seen_plans[id]].region_id] > region_order[wave_map[seen_plans[plan.plan_id]].region_id]: return "计划不能依赖后续区域"
			dependencies.append("p:" + String(id))
		edges["p:" + String(plan.plan_id)] = dependencies
	for wave in waves:
		for id in wave.after_wave_ids:
			for plan_id in wave_map[id].plan_ids:
				if plan_map[plan_id].participates_in_clear: edges["w:" + String(wave.wave_id)].append("p:" + String(plan_id))
	if _has_cycle(edges): return "波次与计划之间存在循环"
	if not _conditions_valid(required_conditions): return "关卡条件未声明"
	for id in required_boss_plan_ids:
		if not plan_map.has(id) or not plan_map[id].is_boss or not plan_map[id].participates_in_clear: return "必需Boss出生计划无效"
	return ""

func _conditions_valid(ids: Array[StringName]) -> bool:
	for id in ids:
		if id.is_empty() or not condition_ids.has(id): return false
	return true

func _has_cycle(edges: Dictionary) -> bool:
	var remaining := edges.duplicate(true)
	while not remaining.is_empty():
		var ready: Array = []
		for id in remaining:
			var waiting := false
			for dependency in remaining[id]:
				if remaining.has(dependency): waiting = true
			if not waiting: ready.append(id)
		if ready.is_empty(): return true
		for id in ready: remaining.erase(id)
	return false
#endregion
