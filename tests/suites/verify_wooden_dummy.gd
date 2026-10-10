extends Node
#region 战斗夹具与验收入口
var demo: Node2D
var session: BattleSession
var target: BattleEntity2D
var other: BattleEntity2D
var body: Node2D
var face: Sprite2D
var base: Sprite2D
var failures: Array[String] = []
var checks: int = 0
var target_hits: int = 0

func _ready() -> void:
	demo = load("res://tests/fixtures/original_damage_demo.tscn").instantiate()
	demo.enable_player_controls = false
	add_child(demo)
	session = demo.session
	session.set_physics_process(false)
	target = demo.dummies[1]
	other = demo.dummies[0]
	body = target.get_node("AnimationAdapter/Visual/Body")
	face = body.get_node("HurtFace")
	base = target.get_node("AnimationAdapter/Visual/Base")
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	await _step(10)
	await _verify_hurt_and_restart()
	await _verify_clock_and_facing()
	await _verify_attack_and_death()
	CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	session.clear_battle()
	demo.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS wooden dummy: %d checks; authored SVG/body pivot, actual damage, repeated hurt restart, recovery, mirroring, pause/slow/hit-stop, five-combo and death" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _on_event(id: String, payload: Array) -> void:
	if id == "battle.attack.hit" and payload.size() == 1 and payload[0].get("battle_id") == session.battle_id and payload[0].get("target_entity_id") == target.entity_id:
		target_hits += 1

func _step(count: int = 1, delta: float = 1.0 / 60.0) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		session.advance_physics(delta)

func _check_rest_pose() -> void:
	_check(body.position.is_equal_approx(Vector2(0, -16)) and is_zero_approx(body.rotation) and body.scale.is_equal_approx(Vector2.ONE), "待机恢复身体的位置、旋转与缩放，无受伤姿态残留")
	_check(body.modulate.is_equal_approx(Color.WHITE) and is_zero_approx(face.modulate.a), "待机恢复颜色并隐藏受伤五官")
#endregion
#region 真实扣血、重复受伤与注册点
func _verify_hurt_and_restart() -> void:
	var clip := (target.get_node("AnimationAdapter/AnimationPlayer") as AnimationPlayer).get_animation(&"hurt")
	_check(is_equal_approx(clip.length, 8.0 / 30.0) and clip.loop_mode == Animation.LOOP_NONE, "预置受伤动画使用30FPS八帧，单次播放")
	_check(base.region_rect == Rect2(0, 164, 100, 16) and (body.get_node("Sprite") as Sprite2D).region_rect == Rect2(0, 0, 100, 164), "同一SVG按底座上缘切分，不改变100×180的脚底注册点")
	_check_rest_pose()
	var root_before := target.global_transform
	var base_before := base.global_transform
	var collision_before := (target.get_node("CollisionShape2D") as Node2D).global_transform
	var hurtbox_before := (target.get_node("Hurtbox/CollisionShape2D") as Node2D).global_transform
	var health_before := target.attributes.get_vital_value(&"health")
	_check(is_equal_approx(target.receive_damage(1.0), 1.0), "通过现有HealthVital入口实际扣血")
	_check(target.action_state.current == BattleActionState2D.State.HURT and target.animation.get_current_action() == &"hurt", "战斗受击状态驱动AnimationPlayer动作")
	_check(is_zero_approx(target.animation.get_playback_time()) and face.modulate.a == 1.0, "受伤从第一帧开始并显示痛苦表情")
	await _step(2)
	_check(body.rotation > 0.10 and body.scale.y < 0.95, "受击峰值有倾斜与短暂压缩")
	_check(base.global_transform.is_equal_approx(base_before) and target.global_transform.is_equal_approx(root_before), "上身运动不会移动底座或角色根节点")
	_check((target.get_node("CollisionShape2D") as Node2D).global_transform.is_equal_approx(collision_before) and (target.get_node("Hurtbox/CollisionShape2D") as Node2D).global_transform.is_equal_approx(hurtbox_before), "受伤视觉不改变物理碰撞或受击范围")
	target.receive_damage(1.0)
	_check(is_zero_approx(target.animation.get_playback_time()) and is_zero_approx(body.rotation) and face.modulate.a == 1.0, "连续命中重新播放hurt，不继承上一击的时间与倾斜")
	await _step(2)
	_check(body.rotation > 0.10, "重复命中仍到达新的受伤峰值")
	_check(is_equal_approx(target.attributes.get_vital_value(&"health"), health_before - 2.0), "两次实际伤害与动画重播独立结算")
	await _step(25)
	_check(target.action_state.current == BattleActionState2D.State.IDLE and target.animation.get_current_action() == &"idle", "硬直结束由战斗状态恢复待机")
	_check_rest_pose()
	var other_body: Node2D = other.get_node("AnimationAdapter/Visual/Body")
	_check(is_zero_approx(other_body.rotation) and other.attributes.get_vital_value(&"health") == 500.0, "相同资源的另一个木桩不共享受伤姿态或生命")
#endregion
#region 战斗时钟与左右镜像
func _verify_clock_and_facing() -> void:
	for facing in [-1, 1]:
		target.animation.set_facing(facing)
		target.receive_damage(1.0)
		await _step(2)
		_check((target.get_node("AnimationAdapter/Visual") as Node2D).scale.x == float(facing), "受伤缩放轨道不覆盖朝向")
		var time_before := target.animation.get_playback_time()
		var pose_before := body.transform
		session.set_paused(true)
		await _step(5)
		_check(is_equal_approx(target.animation.get_playback_time(), time_before) and body.transform.is_equal_approx(pose_before), "菜单暂停冻结受伤动作")
		session.set_paused(false)
		session.request_hit_stop(0.05)
		await _step(2)
		_check(is_equal_approx(target.animation.get_playback_time(), time_before), "受击停顿冻结木桩受伤时间")
		await _step(1)
		session.set_time_scale(0.5)
		time_before = target.animation.get_playback_time()
		await _step(2)
		_check(is_equal_approx(target.animation.get_playback_time() - time_before, 1.0 / 60.0), "慢动作按战斗时钟推进受伤动画")
		session.set_time_scale(1.0)
		await _step(30)
		_check_rest_pose()
		_check((target.get_node("AnimationAdapter/Visual") as Node2D).scale.x == float(facing), "恢复待机不改变镜像")
#endregion
#region 五连击与死亡优先级
func _verify_attack_and_death() -> void:
	target.animation.set_facing(1)
	demo.player.request_attack()
	var queued := -1
	var hurt_seen := false
	for tick in range(190):
		if demo.player.combo.is_active() and demo.player.combo.index != queued:
			queued = demo.player.combo.index
			demo.player.request_attack()
		await _step()
		hurt_seen = hurt_seen or target.action_state.current == BattleActionState2D.State.HURT
	_check(queued == 4 and target_hits == 6 and hurt_seen, "真实五连击对正面目标六次命中可驱动新木桩受伤动画（预约%d、命中%d、受伤%s）" % [queued, target_hits, hurt_seen])
	await _step(30)
	_check_rest_pose()
	target.receive_damage(1.0)
	await _step(2)
	var base_before := base.global_transform
	target.receive_damage(1000.0)
	_check(target.action_state.current == BattleActionState2D.State.DEAD and target.animation.get_current_action() == &"death", "死亡优先于受伤，仍由战斗规则决定")
	_check(is_zero_approx(face.modulate.a), "死亡立即移除受伤表情")
	await _step(40)
	_check(body.rotation < -1.0 and base.global_transform.is_equal_approx(base_before), "死亡上身倒下但底座保持固定")
#endregion
