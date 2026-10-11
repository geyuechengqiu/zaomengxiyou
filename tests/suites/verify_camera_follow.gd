extends Node
#region 真实关卡、原插件与固定输入
const FIRST := Rect2(0,0,2368,1216)
const SECOND := Rect2(2368,0,2176,1216)
var scene: Node2D
var rig: BattleCameraRig2D
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children(): count += count_nodes(child)
	return count

func step(delta: float) -> void:
	await get_tree().physics_frame
	scene.session.advance_physics(delta)

func player_at(x: float, y: float = 1056) -> void:
	scene.player.position = Vector2(x,y)
	scene.player.velocity = Vector2.ZERO
	scene.player.motion.clear_impulse()
	scene.player.move_axis = 0
	scene.player.running = false

func reset_transition() -> void:
	player_at(2300)
	rig.set_region_bounds(FIRST,true)
	rig.advance_camera(1.0/30.0)
	rig.set_region_bounds(SECOND)

func _ready() -> void:
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	# 战斗反馈等系统会创建运行节点；只检查镜头系统负责的子树。
	var authored := count_nodes(scene.get_node("Camera2D")) + count_nodes(scene.get_node("BattleSession/CameraRig"))
	add_child(scene)
	scene.session.set_physics_process(false)
	rig = scene.session.camera_rig
	await get_tree().process_frame
	await get_tree().process_frame
	check(count_nodes(scene.get_node("Camera2D")) + count_nodes(rig) == authored, "镜头、Host、PCam和跟随锚点均预置，启动不创建镜头节点")
	check(Engine.has_singleton("PhantomCameraManager"), "原插件Manager已启用")
	check(rig._host.get_active_pcam() == rig._pcam, "原插件Host选中本会话的预置虚拟镜头")
	check(rig._host.interpolation_mode == PhantomCameraHost.InterpolationMode.MANUAL and rig._pcam.process_mode == Node.PROCESS_MODE_DISABLED, "镜头只有战斗时钟一个更新入口")
	check(not scene.camera.position_smoothing_enabled and scene.camera.zoom == Vector2(0.5,0.5), "不叠加Godot平滑，保持原940×590画面和2倍世界坐标")
	# 隔离AI对固定输入的影响；真实出口资格另由关卡回归验证。
	scene.flow.stop()
	player_at(256)
	rig.set_region_bounds(FIRST,true)
	rig.advance_camera(1.0/30.0)
	check(scene.camera.get_screen_center_position().is_equal_approx(Vector2(940,626)), "原版地面跟随时可见上缘为36世界像素")
	_verify_follow()
	_verify_transition()
	_verify_combat_lock()
	_verify_rates()
	await _verify_clocks()
	await _verify_scope()
	_verify_regions()
	scene.free()
	await get_tree().process_frame
	if failures.is_empty(): print("PASS original camera follow: %d checks; actual Phantom Host/PCam, original30fps 0.2 interpolation, region continuity/backward follow, unlocked bounds, vertical follow, clocks, parallax, scene scopes and cleanup" % checks)
	else:
		for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)
#endregion
#region 原版插值、过区与已清区域反向跟随
func _verify_follow() -> void:
	for input in [Vector2(1500,1056),Vector2(1500,400),Vector2(-100,100),Vector2(3000,2000)]:
		player_at(input.x,input.y)
		rig.advance_camera(1.0/30.0)
		var expected := Vector2(clampf(input.x,940,1428),clampf(input.y,590,626))
		check(scene.camera.global_position.is_equal_approx(expected), "首次区域moveSpeed=1匹配居中裁剪 %s" % input)
		check(scene.camera.get_screen_center_position().is_equal_approx(expected), "实际渲染中心匹配跟随结果")

func _verify_transition() -> void:
	player_at(2300)
	rig.set_region_bounds(FIRST,true)
	rig.advance_camera(1.0/30.0)
	var old_center: Vector2 = scene.camera.get_screen_center_position()
	var old_transform: Transform2D = scene.camera.global_transform
	rig.set_region_bounds(SECOND)
	scene.camera.force_update_scroll()
	check(scene.camera.global_transform == old_transform and scene.camera.get_screen_center_position().is_equal_approx(old_center), "设置新区域保留当前实际画面")
	check(scene.camera.limit_right == 4544 and scene.camera.limit_left == 0, "解锁新右边界时保留已开放地图左边界")
	rig.advance_camera(1.0/30.0)
	check(scene.camera.global_position.is_equal_approx(Vector2(1602.4,626)), "源第1帧=1428+(2300-1428)*0.2")
	check(scene.camera.get_screen_center_position().is_equal_approx(scene.camera.global_position), "硬限界不绕过原版插值")
	rig.advance_camera(1.0/30.0)
	check(is_equal_approx(rig.center.x,1741.92), "源第2帧=1602.4+(2300-1602.4)*0.2")
	player_at(1500)
	var before := rig.center.x
	rig.advance_camera(1.0/30.0)
	check(is_equal_approx(rig.center.x,lerpf(before,1500,0.2)) and rig.center.x < before, "过区途中回头，镜头按原插值向左跟随当前位置")
	rig.advance_camera(1)
	check(absf(rig.center.x-1500) < 0.3, "回头后停下，镜头靠近当前人物而非先前过区目标")
	player_at(3400)
	rig.advance_camera(1.0/30.0)
	check(rig.going_next, "玩家进入新区但实际镜头尚未过区时仍保留过渡标记")
	before = rig.center.x
	player_at(1700)
	rig.advance_camera(1.0/30.0)
	check(is_equal_approx(rig.center.x,lerpf(before,1700,0.2)) and rig.center.x < before, "过渡未完成时再次回头仍可向左跟随")
	player_at(3400)
	rig.advance_camera(10)
	check(not rig.going_next and is_equal_approx(rig.center.x,3400) and scene.camera.limit_left == 0, "实际可见左缘进入新区后结束过渡，已清区域仍开放")
	player_at(1000)
	rig.advance_camera(10)
	check(is_equal_approx(rig.center.x,1000) and is_equal_approx(scene.camera.get_screen_center_position().x,1000), "过区完成后返回已清区域，实际画面仍跟随人物")
	player_at(-100)
	rig.advance_camera(10)
	check(is_equal_approx(rig.center.x,940), "返回时仍遵守整张地图左边界")
	player_at(5000)
	rig.advance_camera(10)
	check(is_equal_approx(rig.center.x,3604) and scene.camera.limit_right == 4544, "回头跟随不会解锁未通关区域的右边界")
	var center := rig.center
	rig.advance_camera(0)
	check(rig.center == center, "零delta不重新定位")
#endregion
#region 战斗区域双向锁定与平滑入区
func _verify_combat_lock() -> void:
	player_at(1200)
	rig.set_region_bounds(FIRST,true)
	rig.advance_camera(1.0/30.0)
	rig.set_combat_locked(true)
	var locked := rig.center.x
	check(rig.get_combat_horizontal_bounds().is_equal_approx(Vector2(260,2140)), "战斗活动范围取可见画面而非整块2368像素区域")
	for x in [1000,2000,1000]:
		player_at(x)
		rig.advance_camera(1)
		check(is_equal_approx(rig.center.x,locked) and is_equal_approx(scene.camera.get_screen_center_position().x,locked), "区域未清理时向左或向右移动均不推动实际镜头")
	rig.set_combat_locked(false)
	for x in [1400,1000]:
		player_at(x)
		rig.advance_camera(1)
		check(is_equal_approx(rig.center.x,x), "区域清理后恢复左右跟随")
	reset_transition()
	var before := rig.center.x
	rig.set_combat_locked(true)
	check(is_equal_approx(rig.center.x,before), "新区战斗锁定不瞬移")
	check(rig.get_combat_horizontal_bounds().is_equal_approx(Vector2(2368,2368)), "过区镜头尚未抵达时不提前开放不可见的右侧")
	player_at(2500)
	rig.advance_camera(1.0/30.0)
	check(is_equal_approx(rig.center.x,lerpf(before,3308,0.2)), "新区锁定只平滑过渡到固定战斗画面")
	check(rig.get_combat_horizontal_bounds().is_equal_approx(Vector2(2368,rig.center.x+940)), "过区活动范围跟随当前插值画面的右边缘")
	player_at(4400)
	rig.set_combat_locked(true)
	rig.advance_camera(10)
	check(is_equal_approx(rig.center.x,3308) and not rig.going_next, "重复同步锁定不重新采样目标，平滑过区完成后保持锁定")
	check(rig.get_combat_horizontal_bounds().is_equal_approx(Vector2(2368,4248)), "新区锁定后右侧限制在可见4248处，不开放到区域4544处")
	player_at(1000)
	rig.advance_camera(10)
	check(is_equal_approx(rig.center.x,3308), "新区域尚未清理时回头不能拉走镜头")
	rig.set_combat_locked(false)
	rig.advance_camera(10)
	check(is_equal_approx(rig.center.x,1000), "新区清理后可以返回已清区域")
#endregion
#region 更新频率、暂停、慢动作与受击停顿
func _verify_rates() -> void:
	var expected := 2300.0-872.0*pow(0.8,30)
	for hz in [15,30,60,120]:
		reset_transition()
		for tick in range(hz): rig.advance_camera(1.0/hz)
		check(absf(rig.center.x-expected) < 0.001, "%dFPS一秒与原30源帧插值相同" % hz)
	reset_transition()
	rig.advance_camera(1)
	check(absf(rig.center.x-expected) < 0.001, "低帧率不改变固定目标过渡耗时")

func _verify_clocks() -> void:
	reset_transition()
	var before := rig.center
	scene.session.set_paused(true)
	await step(10)
	check(rig.center == before and scene.camera.global_position.is_equal_approx(before), "菜单暂停冻结过区")
	scene.session.set_paused(false)
	scene.session.set_time_scale(0.5)
	await step(0.2)
	check(absf(rig.center.x-(2300-(2300-before.x)*pow(0.8,3))) < 0.001, "0.5慢动作只推进0.1战斗秒")
	scene.session.set_time_scale(1)
	before = rig.center
	scene.session.request_hit_stop(0.2)
	await step(0.1)
	check(rig.center == before, "受击停顿冻结跟随")
	await step(0.2)
	check(absf(rig.center.x-(2300-(2300-before.x)*pow(0.8,3))) < 0.001, "停顿结束仅推进剩余0.1秒")
	before = rig.center
	get_tree().paused = true
	await step(1)
	get_tree().paused = false
	check(rig.center == before, "SceneTree暂停冻结插件镜头")
	await get_tree().process_frame
	await get_tree().process_frame
	check(rig.center == before and scene.camera.global_position.is_equal_approx(before), "渲染帧不重复推进镜头")
#endregion
#region 会话隔离、五区域限界、视差和离场
func _verify_scope() -> void:
	var other := load("res://game/levels/biyujing.tscn").instantiate() as Node2D
	other.enable_player_controls = false
	add_child(other)
	other.session.set_physics_process(false)
	await get_tree().process_frame
	await get_tree().process_frame
	var second := other.session.camera_rig as BattleCameraRig2D
	check(second._host.get_active_pcam() == second._pcam and rig._host.get_active_pcam() == rig._pcam, "同优先级同层也只选择本会话镜头")
	var old := rig.center
	var limits := Vector2(scene.camera.limit_left,scene.camera.limit_right)
	other.player.position = Vector2(1200,1056)
	second.advance_camera(1.0/30.0)
	check(rig.center == old and Vector2(scene.camera.limit_left,scene.camera.limit_right) == limits, "另一个会话的全局限界广播不污染当前镜头")
	other.free()
	await get_tree().process_frame
	check(Engine.get_singleton("PhantomCameraManager").get_phantom_camera_2ds().size() == 1, "离场注销原插件虚拟镜头")
	check(rig._host.get_active_pcam() == rig._pcam, "其他会话离场不改活动镜头")

func _verify_regions() -> void:
	var definition := scene.session.catalog.instantiate_definition("levels",&"碧玉径") as BattleLevelDefinition
	for region in definition.regions:
		player_at(region.bounds.get_center().x)
		rig.set_region_bounds(region.bounds,true)
		rig.advance_camera(1.0/30.0)
		check(scene.camera.get_screen_center_position().is_equal_approx(rig.center), "全部五区实际画面与插件输出一致")
		var left: float = scene.camera.get_screen_center_position().x-940
		check(left >= region.bounds.position.x-0.01 and left+1880 <= region.bounds.end.x+0.01, "各区不露出限界外地图")
		var visual := scene.get_node("BattleSession/Actors/Visuals/BiyujingVisual") as BattleMapVisual2D
		visual.refresh_view()
		var far := visual.get_node("FarBackground/far_0_0") as Sprite2D
		check(absf(far.get_global_transform_with_canvas().origin.x+left*0.5*0.04) < 0.01, "远景跟随平滑后的实际可见位置")
	var center := rig.center
	scene.player.attributes.get_vital(&"health").set_current_value(0)
	player_at(100)
	rig.advance_camera(1)
	check(rig.center == center, "原版全部跟随玩家死亡时停止跟随")
	rig.stop()
	rig.advance_camera(1)
	check(rig.center == center, "结束/卸载停止镜头调度")
#endregion
