extends Node
#region 真实角色、GAS无双和固定战斗时钟
var scene: Node2D
var session: BattleSession
var player: BattleEntity2D
var effect: BattleWushuangEffect2D
var checks: int = 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func tick(delta: float) -> void:
	await get_tree().physics_frame
	session.advance_physics(delta)

func visible_ghosts() -> int:
	var count := 0
	for ghost in effect._ghosts:
		if ghost.visible: count += 1
	return count

func node_count(node: Node) -> int:
	var count := 1
	for child in node.get_children(): count += node_count(child)
	return count

func _ready() -> void:
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	add_child(scene)
	session = scene.session
	player = scene.player
	session.set_physics_process(false)
	scene.flow.stop()
	effect = player.animation.get_node("WushuangEffect") as BattleWushuangEffect2D
	player.global_position = Vector2(800,1056)
	await tick(0.1)
	var authored_nodes := node_count(effect)
	player.wushuang.add_rage(10000)
	check(player.try_activate_skill(&"sunwukong_wushuang"), "使用真实GAS入口激活满值无双")
	for index in range(36): await tick(1.0/30.0)
	check(effect.active and effect.halo.visible, "待机仍保留实时红色轮廓辉光")
	check(effect.spawn_count == 6 and effect.get_active_ghost_count() == 5, "保留原0.2秒采样和1秒残影寿命")
	check(visible_ghosts() == 0, "待机旧姿态不叠在人物头部、身体或武器上")
	var origin := player.global_position
	var snapshot := effect._ghosts[1]
	var snapshot_position := snapshot.global_position
	player.move_axis = 1
	player.running = true
	await tick(0.05)
	check(player.global_position.x > origin.x and visible_ghosts() > 0, "跑动时尚未过期的旧位置快照正常显示拖尾")
	check(snapshot.global_position.is_equal_approx(snapshot_position), "移动不带走已捕获残影的位置")
	for ghost in effect._ghosts:
		if ghost.visible:
			check(ghost.global_position.distance_to(player.animation.global_position) >= 4.0, "可见残影与人物保持至少2个原素材像素距离")
	var age: float = effect._ages[1]
	var spawn_count := effect.spawn_count
	var alpha := snapshot.modulate.a
	session.set_paused(true)
	await tick(1)
	check(effect._ages[1] == age and effect.spawn_count == spawn_count and snapshot.modulate.a == alpha, "暂停不推进残影寿命、采样或透明度")
	session.set_paused(false)
	session.set_time_scale(0.5)
	await tick(0.1)
	check(is_equal_approx(effect._ages[1]-age,0.05), "慢动作只缩放一次残影消散时间")
	session.set_time_scale(1)
	player.move_axis = 0
	player.global_position = origin
	player.velocity = Vector2.ZERO
	await tick(0.01)
	check(not snapshot.visible, "返回旧快照位置后隐藏重合快照")
	player.animation.set_facing(-1)
	await tick(0.01)
	check(not snapshot.visible and effect.live_mirror.get_skeleton().get_scale_x() == -1.0, "原地转向不叠加旧朝向，实时红光跟随当前朝向")
	for index in range(33): await tick(1.0/30.0)
	check(visible_ghosts() == 0 and effect.halo.visible, "停止后保持单一人物与红光")
	player.move_axis = -1
	player.running = true
	await tick(0.75)
	check(visible_ghosts() > 0 and effect.get_active_ghost_count() <= 5, "低帧率移动保留拖尾且存活残影数量有界")
	check(node_count(effect) == authored_nodes, "仍复用全部预置残影槽，不新增节点")
	player.statuses.remove_status(&"normal_wushuang_visual")
	check(not effect.active and not effect.halo.visible, "移除无双立即撤销实时红光")
	await tick(1.05)
	check(effect.get_active_ghost_count() == 0 and visible_ghosts() == 0, "无双结束后残影按原寿命消散干净")
	player.wushuang.add_rage(10000)
	check(player.try_activate_skill(&"sunwukong_wushuang"), "重新激活无双不残留旧表现状态")
	await tick(0.4)
	player.attributes.get_vital(&"health").set_current_value(0)
	check(not effect.active and not effect.halo.visible and effect.get_active_ghost_count() == 0 and visible_ghosts() == 0, "死亡立即清空无双辉光与全部残影")
	scene.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS Wushuang visual: %d checks; stationary/turn/return overlap, moving trails, original sampling/fade, clocks, fixed pool, end/death cleanup" % checks)
	else:
		for failure in failures: push_error(failure)
	get_tree().quit(0 if failures.is_empty() else 1)
#endregion
