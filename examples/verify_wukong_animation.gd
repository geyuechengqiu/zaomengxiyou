extends Node
#region 验收状态
var failures: Array[String] = []
var checks: int = 0
var demo: Node2D
var session: BattleSession
var player: BattleEntity2D
var completed: Array[StringName] = []
var loops: Array[StringName] = []
var hits: Array[Dictionary] = []
#endregion
#region 验收入口
func _ready() -> void:
	demo = load("res://examples/wukong_platform_demo.tscn").instantiate()
	demo.enable_player_controls = false
	add_child(demo)
	demo.set_physics_process(false)
	session = demo.session
	session.set_physics_process(false)
	player = demo.player
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	_verify_source_mapping()
	await _step(1.0 / 60.0, 6)
	await _verify_adapter()
	await _verify_combat()
	await _verify_platform()
	CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	session.clear_battle()
	demo.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS wukong animation: %d checks; native Spine, all skins, mirroring, GAS frame-4 hit, state isolation, real 2D platforms and clock" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, text: String) -> void:
	checks += 1
	if not condition:
		failures.append(text)

func _step(delta: float, count: int = 1) -> void:
	for i in range(count):
		await get_tree().physics_frame
		session.advance_physics(delta)

func _on_event(event_id: String, payload: Array) -> void:
	if event_id == "battle.attack.hit" and payload.size() == 1 and payload[0].get("battle_id") == session.battle_id:
		hits.append(payload[0])
#endregion
#region 原资源内容与数据元信息
func _verify_source_mapping() -> void:
	var mapping: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle2d/source_mapping.json"))
	for item in mapping.unchanged_runtime_assets:
		_check(FileAccess.get_sha256("res://" + item.path) == item.sha256, "原生资源内容保持不变：" + item.path)
	var data := player.animation.profile.skeleton_data as SpineSkeletonDataResource
	_check(data.get_version() == mapping.spine_version and data.get_fps() == mapping.source_fps, "原生骨架版本与素材帧率可溯源")
	_check(data.get_bones().size() == mapping.bone_count and data.get_slots().size() == mapping.slot_count and data.get_animations().size() == mapping.animation_count, "原骨骼、槽位及全动作保留")
	_check(data == demo.right_target.animation.profile.skeleton_data, "Spine 定义数据只读共享")
	var definition := session.catalog.instantiate_definition("characters", &"孙悟空") as BattleEntityDefinition
	_check(definition.scene == load("res://data/battle2d/sunwukong_2d.tscn"), "PackedScene 只读共享，通过 instantiate 隔离运行节点")
#endregion
#region 原生动画、注册点与全部皮肤
func _verify_adapter() -> void:
	var adapter := player.animation as SpineAnimationAdapter
	var other := demo.right_target.animation as SpineAnimationAdapter
	adapter.action_completed.connect(func(action): completed.append(action))
	adapter.action_looped.connect(func(action): loops.append(action))
	var frames := {&"idle": 35, &"move": 25, &"run": 16, &"jump": 20, &"fall": 17, &"hurt": 8, &"death": 31, &"attack_1": 10}
	for action in frames:
		_check(adapter.play_action(action, true), "原生动作可播放：" + String(action))
		_check(is_equal_approx(adapter.get_action_duration(action), frames[action] / 30.0), "原版 30 fps 动作时长：" + String(action))
		adapter.advance_animation(0.07)
		_check(adapter.get_playback_progress() > 0.0, "可读取播放进度：" + String(action))
	adapter.set_skins([])
	adapter.play_action(&"idle", true)
	_check(absf(adapter.get_visual_bounds_global().end.y - player.global_position.y) < 0.02, "基础待机脚底原点固定校准")
	_check(adapter.get_draw_order().size() == 34, "保留原版 34 个槽位层序")
	adapter.play_action(&"attack_1", true)
	adapter.advance_animation(0.18)
	var pose_position := player.global_position
	var collision_transform := (player.get_node("CollisionShape2D") as Node2D).global_transform
	var duration := adapter.get_action_duration(&"attack_1")
	var progress := adapter.get_playback_progress()
	var track_time := adapter.get_track_time()
	var order := adapter.get_draw_order()
	var weapon_right := adapter.get_socket_global_transform(&"weapon").origin - player.global_position
	var point_right := player.get_attack_position() - player.global_position
	var rect_right := player.get_attack_rect_global()
	adapter.set_facing(-1)
	var weapon_left := adapter.get_socket_global_transform(&"weapon").origin - player.global_position
	var point_left := player.get_attack_position() - player.global_position
	_check(absf(weapon_right.x + weapon_left.x) < 0.002 and absf(weapon_right.y - weapon_left.y) < 0.002, "攻击中武器挂点左右镜像正确")
	_check(point_left.is_equal_approx(Vector2(-point_right.x, point_right.y)), "原版攻击中心左右镜像正确")
	_check(is_equal_approx(player.get_attack_rect_global().end.x, player.global_position.x) and is_equal_approx(rect_right.position.x, player.global_position.x), "攻击框分别位于左侧与右侧")
	_check(player.scale == Vector2.ONE and collision_transform == (player.get_node("CollisionShape2D") as Node2D).global_transform, "朝向不镜像角色物理碰撞体")
	_check(is_equal_approx(adapter.get_track_time(), track_time), "镜像不重置动作时间")
	adapter.set_facing(1)
	var skins := adapter.get_available_skins()
	_check(skins.size() == 206, "资源包含 206 个非空原版皮肤")
	for skin in skins:
		_check(adapter.set_skin(skin), "原生皮肤可切换：" + String(skin))
		_check(adapter.get_playback_progress() == progress and adapter.get_action_duration(&"attack_1") == duration and adapter.get_track_time() == track_time, "换皮肤不改变动作时长或时间：" + String(skin))
		_check(player.global_position == pose_position and adapter.get_draw_order() == order, "换皮肤不改变位置及动画层序：" + String(skin))
		_check((adapter.get_socket_global_transform(&"weapon").origin - player.global_position).is_equal_approx(weapon_right), "装备注册点不挪动武器骨骼：" + String(skin))
	_check(adapter.set_skins([&"套装/2", &"武器/weapon2"]), "身体套装和武器可独立组合")
	adapter.play_action(&"idle", true)
	_check(adapter.get_slot_attachment_name(&"wq_武器").begins_with("武器/weapon2/"), "武器挂在原版武器槽位")
	_check(adapter.is_socket_active(&"weapon") and not adapter.is_socket_active(&"weapon_long"), "挂点查询区分可见普通武器和隐藏长棍槽位")
	var foot_attachment := adapter.get_slot_attachment_name(&"yf_脚1")
	_check(foot_attachment.contains("armor2/") or foot_attachment.begins_with("套装/2/"), "套装脚部附件来自原版衣服：" + foot_attachment)
	_check(other.get_skin_names().has(&"武器/weapon7_7"), "另一同配置实例不受换装影响")
	var before := adapter.get_skin_names()
	_check(not adapter.set_skin(&"missing") and adapter.get_skin_names() == before, "无效皮肤失败且不污染当前外观")
	_check(not adapter.play_action(&"missing") and adapter.get_current_action() == &"idle", "无效动作失败且不污染当前动作")
	adapter.play_action(&"hurt", true)
	completed.clear()
	adapter.advance_animation(1.0)
	adapter.advance_animation(1.0)
	_check(completed == [&"hurt"], "非循环动作仅发送一次完成通知并保持终帧")
	adapter.play_action(&"idle", true)
	loops.clear()
	adapter.advance_animation(adapter.get_action_duration(&"idle") + 0.02)
	_check(loops.has(&"idle"), "循环动作发 loop 通知")
	adapter.play_action(&"idle", true)
	var stopped_time := adapter.get_track_time()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(adapter.get_track_time() == stopped_time, "渲染帧不会额外推进手动 Spine 时钟")
#endregion
#region GAS 时序与战斗状态独立
func _verify_combat() -> void:
	var anim := player.animation
	_check(player.attributes.get_value(&"atk") == 26 and player.attributes.get_value(&"hpMax") == 275, "角色初始属性来自原版 Role 2001")
	_check(player.action_state.grounded, "真实平台碰撞确认落地")
	anim.play_action(&"death", true)
	_check(player.is_alive() and player.action_state.can_attack(true), "仅播放死亡动画不决定死亡或攻击许可")
	await _step(1.0 / 60.0)
	anim.set_facing(1)
	hits.clear()
	var right_hp: float = demo.right_target.attributes.get_vital_value(&"health")
	var left_hp: float = demo.left_target.attributes.get_vital_value(&"health")
	_check(player.try_attack(), "地面待机可发动 GAS 普攻")
	_check(not player.try_attack(), "战斗攻击锁定期间禁止重入")
	await _step(1.0 / 60.0, 7)
	_check(hits.is_empty(), "素材第 4 帧之前无伤害")
	await _step(1.0 / 60.0)
	_check(hits.size() == 1 and is_equal_approx(player.last_impact_time, 4.0 / 30.0), "GAS 在素材第 4 帧命中一次")
	_check(demo.right_target.attributes.get_vital_value(&"health") == right_hp - 21 and demo.left_target.attributes.get_vital_value(&"health") == left_hp, "右向命中右靶并复用 GAS atk-phyDef")
	await _step(1.0 / 60.0, 15)
	_check(player.action_state.current == BattleActionState2D.State.IDLE, "战斗规则独立释放攻击锁定")
	anim.set_facing(-1)
	hits.clear()
	_check(player.try_activate_skill(&"sunwukong_attack1"), "直接技能入口也进入普攻动作状态")
	await _step(1.0 / 60.0, 8)
	_check(hits.size() == 1 and demo.left_target.attributes.get_vital_value(&"health") == left_hp - 21, "左右翻转后命中左靶")
	await _step(1.0 / 60.0, 15)
	player.receive_damage(10)
	_check(player.action_state.current == BattleActionState2D.State.HURT and not player.try_attack(), "受击由伤害状态禁止攻击")
	anim.action_completed.emit(&"hurt")
	_check(player.action_state.current == BattleActionState2D.State.HURT and not player.try_attack(), "伪造动画完成不会跳过受击锁定")
	await _step(1.0 / 60.0, 18)
	_check(player.is_alive() and player.action_state.current == BattleActionState2D.State.IDLE, "受击锁定按战斗时间恢复")
	var position_before := player.position
	var track_before := (anim as SpineAnimationAdapter).get_track_time()
	var elapsed_before := session.clock.elapsed
	session.set_paused(true)
	await _step(1.0 / 60.0, 8)
	_check(player.position == position_before and (anim as SpineAnimationAdapter).get_track_time() == track_before and session.clock.elapsed == elapsed_before, "暂停冻结物理、动画和战斗时间")
	_check(not player.try_attack() and not player.try_jump(), "暂停禁止战斗命令")
	anim.set_equipment_skin(&"weapon", &"武器/weapon3")
	_check((anim as SpineAnimationAdapter).get_track_time() == track_before and player.position == position_before, "暂停中换装也不重置位置或播放进度")
	session.set_paused(false)
	session.set_time_scale(0.25)
	await _step(0.04)
	_check(is_equal_approx(session.clock.elapsed - elapsed_before, 0.01) and is_equal_approx((anim as SpineAnimationAdapter).get_track_time() - track_before, 0.01), "慢动作统一缩放动画及战斗时钟")
	session.set_time_scale(1.0)
	session.request_hit_stop(0.1)
	track_before = (anim as SpineAnimationAdapter).get_track_time()
	await _step(0.05)
	_check((anim as SpineAnimationAdapter).get_track_time() == track_before, "受击停顿冻结动画")
	await _step(0.1)
	_check(is_equal_approx((anim as SpineAnimationAdapter).get_track_time() - track_before, 0.05), "停顿结束只推进剩余战斗时间")
	player.receive_damage(10000)
	_check(not player.is_alive() and player.action_state.current == BattleActionState2D.State.DEAD and anim.get_current_action() == &"death", "生命耗尽即刻进入死亡，与动画是否结束无关")
	anim.action_completed.emit(&"death")
	_check(not player.try_attack() and not player.try_jump() and player.action_state.current == BattleActionState2D.State.DEAD, "死亡动画完成不会复活或恢复攻击许可")
	await _step(1.0 / 60.0, 70)
	_check(player.action_state.current == BattleActionState2D.State.DEAD and anim.get_playback_progress() == 1.0, "死亡终帧保持，死亡状态持续")
#endregion
#region 实际平台跳跃、落地与碰撞
func _verify_platform() -> void:
	demo.respawn()
	player = demo.player
	await _step(1.0 / 60.0, 6)
	player.position.x = 780
	player.move_axis = 1.0
	_check(player.try_jump(), "落地可跳跃")
	_check(not player.try_attack() and not player.try_activate_skill(&"sunwukong_attack1"), "普攻遵守原版只允许地面的规则")
	player.animation.action_completed.emit(&"jump")
	_check(player.action_state.current == BattleActionState2D.State.TAKEOFF, "跳跃动画完成不会跳过起跳状态或让空中角色落地")
	await _step(1.0 / 60.0, 25)
	_check(player.position.y < 540 and player.position.x > 850, "真实固定物理运动越过平台边缘")
	player.move_axis = 0.0
	await _step(1.0 / 60.0, 45)
	_check(player.action_state.grounded and absf(player.position.y - 520) < 0.3, "碰撞落在上方 2D 平台，脚底原点位于平台顶面")
	player.position = Vector2(2040, 645)
	player.velocity = Vector2.ZERO
	player.move_axis = 1.0
	await _step(1.0 / 60.0, 90)
	_check(player.position.x <= 2128.2, "碰撞体不会穿过墙体")
	var position_before := player.position
	session.set_paused(true)
	await _step(1.0 / 60.0, 10)
	_check(player.position == position_before, "暂停后墙体碰撞处不会继续移动")
	session.set_paused(false)
#endregion
