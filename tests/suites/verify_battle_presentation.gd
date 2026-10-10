extends Node
#region 公共表现归属、时钟、事件隔离与生命周期
var checks: int = 0
var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _count_nodes(node: Node) -> int:
	var count := 1
	for child in node.get_children():
		count += _count_nodes(child)
	return count

func _hit(session: BattleSession, target: BattleEntity2D, amount: int) -> void:
	session.publish_event(&"battle.attack.hit", null, target, {"damage": amount, "normal_damage": amount})

func _ready() -> void:
	var demo := load("res://tests/fixtures/original_damage_demo.tscn").instantiate() as Node2D
	demo.enable_player_controls = false
	var authored_count := _count_nodes(demo)
	add_child(demo)
	var session: BattleSession = demo.session
	session.set_physics_process(false)
	await get_tree().process_frame
	var presentation := session.presentation
	var rows := presentation.number_rows
	var left: BattleEntity2D = demo.dummies[0]
	var right: BattleEntity2D = demo.dummies[1]
	_check(_count_nodes(demo) == authored_count, "静态关卡的管理器、目标视图及池由场景预置，启动不补建")
	_check(presentation.get_parent() == session and rows.get_parent().get_parent() == presentation, "公共表现和唯一跳字池归战斗会话")
	for actor: BattleEntity2D in session.get_entities():
		_check(not actor.has_node("CombatFeedback") and not actor.has_node("DamageNumbers"), "公共表现不挂在角色根节点")
		_check(actor.feedback.get_parent() == presentation.entity_views and actor.feedback.number_rows == rows, "角色只查询公共视图，所有目标共用池")
	_check(left.feedback != right.feedback, "同定义目标的血条、闪光及命中记录独立")
	_hit(session, left, 12)
	_hit(session, right, 34)
	var active := rows.get_active_numbers()
	_check(active.size() == 2 and active[0].number == 12 and active[1].number == 34, "不同目标数字独立且按命中顺序排列")
	_check(left.feedback.hit_count == 1 and right.feedback.hit_count == 1, "集中订阅事件只分发一次给对应目标")
	session.advance_physics(0.1)
	_check(is_equal_approx(active[0].elapsed, 0.1) and is_equal_approx(active[1].elapsed, 0.1), "存在三个实体时公共池仍每tick只推进一次")
	var at := active[0].position
	left.position += Vector2(80, 0)
	left.animation.set_facing(-1)
	session.set_paused(true)
	session.advance_physics(0.5)
	_check(is_equal_approx(active[0].elapsed, 0.1), "战斗暂停冻结公共跳字")
	_check(left.feedback.global_transform == left.global_transform and active[0].position == at, "目标视图随目标移动；已生成跳字保持屏幕位置")
	session.set_paused(false)
	session.request_hit_stop(0.2)
	session.advance_physics(0.2)
	_check(is_equal_approx(active[0].elapsed, 0.1), "受击停顿冻结公共表现")
	session.set_time_scale(0.5)
	session.advance_physics(0.2)
	_check(is_equal_approx(active[0].elapsed, 0.2), "慢动作统一缩放公共表现")
	session.set_time_scale(1.0)
	var peer_session := BattleSystem.create_session(self, "res://data/battle2d/single_attack/manifest.json", 77)
	peer_session.set_physics_process(false)
	var peer := peer_session.spawn_entity_2d("monsters", &"木桩")
	_check(peer.feedback != null and peer.feedback.get_parent() == peer_session.presentation.entity_views and not peer.has_node("CombatFeedback"), "动态出生目标使用公共管理器创建表现实例")
	_hit(peer_session, peer, 56)
	_check(rows.get_active_count() == 2 and peer_session.presentation.number_rows.get_active_count() == 1, "不同战斗事件、数字池及记录相互隔离")
	var old_view := left.feedback
	var old_attributes := left.attributes
	session.despawn_entity(left.entity_id)
	_check(not old_view.visible and not old_attributes.snapshot_changed.is_connected(old_view._refresh_health), "离场立即隐藏目标视图并断开属性监听")
	_check(rows.get_active_count() == 2, "目标离场不删除已经生成的数字")
	await get_tree().process_frame
	session.advance_physics(0.1)
	_check(is_equal_approx(active[0].elapsed, 0.3) and active[0].visible, "目标释放后数字仍独立播放")
	session.advance_physics(0.7)
	_check(rows.get_active_count() == 0 and rows.get_pool_stats().cached == 2, "离场目标数字自然结束并进入共享池")
	var created := rows.created_count
	_hit(session, right, 78)
	_check(rows.created_count == created and rows.reused_count > 0, "其他目标复用此前目标的跳字节点")
	var peer_row := peer_session.presentation.number_rows.get_active_numbers()[0]
	session.clear_battle()
	_check(rows.get_active_count() == 0 and rows.get_pool_stats().cached == 0, "清理战斗释放公共活动与缓存数字")
	_check(peer_row.visible and peer_row.elapsed == 0.0, "另一场战斗不会被推进或清理")
	var manager_ref: WeakRef = weakref(presentation)
	var rows_ref: WeakRef = weakref(rows)
	demo.free()
	_check(manager_ref.get_ref() == null and rows_ref.get_ref() == null, "卸载场景释放公共管理器和跳字池")
	peer_session.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS battle presentation: %d checks; authored shared manager, cross-target pooling, once-per-tick clock, pause/hit-stop/slow motion, independent sessions, despawn and cleanup" % checks)
		get_tree().quit()
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
#endregion
