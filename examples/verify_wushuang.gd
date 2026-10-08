extends Node
#region 真实场景、预置节点与固定战斗时钟
var demo: Node2D
var player: BattleEntity2D
var session: BattleSession
var effect: BattleWushuangEffect2D
var failures: Array[String] = []
var checks: int = 0

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _paths(node: Node) -> Array[String]:
	var result: Array[String] = []
	for child in node.get_children():
		result.append(String(node.get_path_to(child)))
		for path in _paths(child): result.append("%s/%s" % [child.name, path])
	return result

func _fresh() -> void:
	if is_instance_valid(demo): demo.free()
	demo = load("res://examples/wukong_skills_demo.tscn").instantiate()
	demo.enable_player_controls = false
	var paths := _paths(demo)
	add_child(demo)
	session = demo.session
	session.set_physics_process(false)
	player = demo.player
	effect = player.get_node("AnimationAdapter/WushuangEffect")
	_check(paths == _paths(demo), "全部表现节点均预置")
	for tick in range(8): await _step()

func _step(delta: float = 1.0 / 60.0) -> void:
	await get_tree().physics_frame
	session.advance_physics(delta)

func _key(code: int, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	return event

func _ready() -> void:
	await _fresh()
	await _verify_pose()
	_verify_instance_isolation()
	await _verify_clock()
	await _verify_cleanup()
	await _verify_input()
	demo.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS ordinary Wushuang: %d checks; red glow/original30fps pulse/0.2s snapshots/1s linear fade, authored bounded GPU pool, frozen pose/skin/facing/world position, independent actions, combat clocks, expiry/death/exit and Core remapping" % checks)
		get_tree().quit()
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)
#endregion
#region 同配置角色拥有独立状态、纹理和材质
func _verify_instance_isolation() -> void:
	var other := session.spawn_entity_2d("characters", &"孙悟空", Vector2(100, 650))
	var other_effect := other.get_node("AnimationAdapter/WushuangEffect") as BattleWushuangEffect2D
	_check(not other_effect.active and not other_effect.halo.visible, "无双状态不污染第二个同配置人物")
	_check(other_effect.halo.material != effect.halo.material and other_effect.halo.texture != effect.halo.texture, "同配置人物拥有独立辉光材质与视口纹理")
	var ghost := other_effect.get_node("GhostPool/Ghost1") as Sprite2D
	_check(ghost.material != effect.get_node("GhostPool/Ghost1").material, "残影材质按实例隔离")
	other_effect.halo.material.set_shader_parameter("blur_width", 3.0)
	_check(not is_equal_approx(float(effect.halo.material.get_shader_parameter("blur_width")), 3.0), "另一角色的材质调整不改变悟空辉光")
	other.free()
#endregion
#region 真实无双意图、独立动作与冻结姿态
func _verify_pose() -> void:
	_check(effect.glow_color == Color("ff3000") and effect.spawn_interval == 0.2 and effect.ghost_lifetime == 1, "原版悟空颜色与采样时长")
	_check(not effect.active and effect.get_node("GhostPool").get_child_count() == 6, "初始隐藏，预置6个快照槽")
	_check(player.try_activate_skill(&"sunwukong_attack1"), "先释放普通攻击")
	var cast := player.attack_instance
	var action := player.animation.get_current_action()
	_check(player.request_skill_operation(&"wushuang", &"sunwukong_wushuang"), "无双意图激活GAS表现状态")
	_check(effect.active and effect.halo.visible and player.statuses.has_status(&"normal_wushuang_visual"), "状态施加同步显示红光")
	_check(player.attack_instance == cast and cast.active and player.animation.get_current_action() == action, "不打断当前攻击或改变动作许可")
	_check(not player.try_activate_skill(&"sunwukong_wushuang"), "重复激活不刷新持续时间")
	for tick in range(12): await _step()
	_check(effect.spawn_count == 1 and effect.get_active_ghost_count() == 1, "0.2秒生成一个残影")
	var ghost := effect.get_node("GhostPool/Ghost1") as Sprite2D
	var mirror := ghost.get_node("Capture/Body") as BattleSpinePoseMirror2D
	var source := player.animation.get_node("SpineVisual") as SpineSprite
	_check(mirror.get_skeleton_data_res() == source.get_skeleton_data_res(), "共用骨架和图集")
	for index in range(source.get_skeleton().get_bones().size()):
		var from: SpineBonePose = source.get_skeleton().get_bones()[index].get_pose()
		var to: SpineBonePose = mirror.get_skeleton().get_bones()[index].get_pose()
		_check(is_equal_approx(from.get_world_x(), to.get_world_x()) and is_equal_approx(from.get_world_y(), to.get_world_y()), "精确捕获已解算骨骼")
	var transform := ghost.global_transform
	var skin := mirror._skin
	var bone_x: float = mirror.get_skeleton().get_bones()[4].get_pose().get_world_x()
	player.position.x += 100
	player.animation.set_facing(-1)
	player.animation.set_skins([&"套装/2", &"武器/weapon2"])
	await _step(0.1)
	_check(ghost.global_transform.is_equal_approx(transform) and mirror._skin == skin, "旧残影不随人物移动、转身或换皮肤")
	_check(is_equal_approx(mirror.get_skeleton().get_bones()[4].get_pose().get_world_x(), bone_x), "旧残影不继续播放骨骼动画")
	_check(is_equal_approx(ghost.modulate.a, 0.9), "1秒线性淡出")
	await _step(0.1)
	var left := effect.get_node("GhostPool/Ghost2/Capture/Body") as BattleSpinePoseMirror2D
	_check(left.get_skeleton().get_scale_x() < 0 and left._skin_names == player.animation.get_skin_names(), "新残影记录新朝向和皮肤")
	_check(effect.get_node("GhostPool").get_child(-1).name == &"Ghost2", "复用槽位仍保留原版新残影在旧残影之上的层序")
#endregion
#region 暂停、停顿、慢动作、原版辉光边界与固定池
func _verify_clock() -> void:
	var elapsed := effect.elapsed
	var count := effect.spawn_count
	var ghost := effect.get_node("GhostPool/Ghost1") as Sprite2D
	var alpha := ghost.modulate.a
	session.set_paused(true)
	await _step(1.0)
	_check(effect.elapsed == elapsed and effect.spawn_count == count and ghost.modulate.a == alpha, "暂停冻结全部表现")
	session.set_paused(false)
	session.request_hit_stop(0.1)
	await _step(0.1)
	_check(effect.elapsed == elapsed, "受击停顿冻结无双表现")
	session.set_time_scale(0.5)
	await _step(0.2)
	_check(is_equal_approx(effect.elapsed - elapsed, 0.1), "慢动作只乘一次")
	session.set_time_scale(1.0)
	var ids: Array[int] = []
	for child in effect.get_node("GhostPool").get_children(): ids.append(child.get_instance_id())
	ids.sort()
	var tween_count := get_tree().get_processed_tweens().size()
	var maximum_tweens := tween_count
	for tick in range(360):
		await _step()
		maximum_tweens = maxi(maximum_tweens, get_tree().get_processed_tweens().size())
	var after: Array[int] = []
	for child in effect.get_node("GhostPool").get_children(): after.append(child.get_instance_id())
	after.sort()
	_check(ids == after and effect.get_active_ghost_count() <= 5 and effect.spawn_count >= 30, "连续采样复用固定池，同屏不超过5个残影")
	_check(maximum_tweens <= tween_count, "不为每个残影创建Tween")
	await _fresh()
	player.try_activate_skill(&"sunwukong_wushuang")
	for tick in range(60): await _step()
	_check(is_equal_approx(float(effect.halo.material.get_shader_parameter("blur_width")), 40), "第30源帧到达40像素宽度")
	for tick in range(62): await _step()
	_check(is_equal_approx(float(effect.halo.material.get_shader_parameter("blur_width")), 9), "保留原版小于0才反向的边界")
	var width := float(effect.halo.material.get_shader_parameter("blur_width"))
	await _fresh()
	player.try_activate_skill(&"sunwukong_wushuang")
	for tick in range(61): await _step(1.0 / 30.0)
	_check(is_equal_approx(float(effect.halo.material.get_shader_parameter("blur_width")), width), "辉光不依赖Godot物理次数")
	await _step(0.75)
	_check(effect.get_active_ghost_count() <= 5, "低帧率仍只保留未过期采样")
#endregion
#region 到期自然消散、死亡与离场立即清理
func _verify_cleanup() -> void:
	var instance := player.statuses.get_status(&"normal_wushuang_visual")
	await _step(instance.remaining_duration + 0.01)
	_check(not effect.active and not effect.halo.visible and not player.statuses.has_status(&"normal_wushuang_visual"), "15秒到期撤销辉光和状态")
	await _step(1.1)
	_check(effect.get_active_ghost_count() == 0, "旧残影自然消散")
	_check(player.try_activate_skill(&"sunwukong_wushuang"), "结束后可以再次预览")
	await _step(0.25)
	player.attributes.get_vital(&"health").set_current_value(0)
	_check(not effect.active and not effect.halo.visible and effect.get_active_ghost_count() == 0, "死亡同步清理")
	_check(not player.try_activate_skill(&"sunwukong_wushuang"), "死亡无法重新激活")
	await _fresh()
	player.try_activate_skill(&"sunwukong_wushuang")
	await _step(0.25)
	var id := effect.get_instance_id()
	session.despawn_entity(player.entity_id)
	_check(effect.get_active_ghost_count() == 0, "离场立即清理")
	await get_tree().process_frame
	_check(not is_instance_id_valid(id), "离场释放预置视口与GPU快照")
#endregion
#region 默认空格与重映射继续使用Core意图
func _verify_input() -> void:
	await _fresh()
	player.operations.enabled = true
	Input.parse_input_event(_key(KEY_SPACE))
	await _step()
	Input.parse_input_event(_key(KEY_SPACE, false))
	await _step()
	_check(effect.active, "默认空格触发")
	player.statuses.remove_status(&"normal_wushuang_visual")
	var bindings := CoreSystem.operation_manager.bindings
	_check(bindings.set_binding(&"battle_player.wushuang", _key(KEY_B), false), "无双支持重映射")
	Input.parse_input_event(_key(KEY_SPACE))
	await _step()
	Input.parse_input_event(_key(KEY_SPACE, false))
	await _step()
	_check(not effect.active, "改键后旧空格不触发")
	Input.parse_input_event(_key(KEY_B))
	await _step()
	Input.parse_input_event(_key(KEY_B, false))
	await _step()
	_check(effect.active, "新按键无需修改人物逻辑")
	bindings.set_binding(&"battle_player.wushuang", _key(KEY_SPACE), false)
#endregion
