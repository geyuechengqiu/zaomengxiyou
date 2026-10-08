extends SceneTree
#region 完整场景重载与注册生命周期验收
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _count_nodes(node: Node) -> int:
	var total := 1
	for child in node.get_children():
		total += _count_nodes(child)
	return total

func _verify() -> void:
	var core := root.get_node("CoreSystem")
	var loaded := change_scene_to_file("res://examples/single_attack_demo.tscn")
	_check(loaded == OK, "能够直接打开预置测试场景")
	await process_frame
	await process_frame
	var demo := current_scene
	demo.session.set_physics_process(false)
	var before: int = _count_nodes(demo)
	var old_battle: StringName = demo.session.battle_id
	var old_controller: StringName = demo.operations.controller.controller_id
	var old_machine: StringName = demo.player.action_state.registration_id
	demo.player.receive_damage(10000)
	demo.dummies[1].receive_damage(10000)
	_check(not demo.player.is_alive() and not demo.dummies[1].is_alive(), "重置之前包含真实死亡状态")
	demo.reload_scene()
	await process_frame
	await process_frame
	demo = current_scene
	demo.session.set_physics_process(false)
	_check(demo.session.battle_id != old_battle and demo.session.get_entities().size() == 3, "重载分配新会话并注册三个预置实体")
	_check(_count_nodes(demo) == before, "重载节点数量一致，未累积运行时节点")
	_check(demo.player.is_alive() and demo.dummies[1].attributes.get_vital_value(&"health") == 70, "重置生命、死亡状态与木桩")
	_check(core.operation_manager.get_controller(old_controller) == null and core.state_machine_manager.get_state_machine(old_machine) == null, "旧控制器与Core动作机全部注销")
	demo.menu.set_open(true)
	_check(demo.session.clock.paused and not demo.operations.controller.has_control(), "预置菜单暂停战斗并持有控制权")
	demo.menu.set_open(false)
	_check(not demo.session.clock.paused and demo.operations.controller.has_control(), "关闭预置菜单恢复原控制权")
	if failures.is_empty():
		print("PASS scene reload: %d checks; authored nodes, death reset, registration cleanup and modal controls" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
#endregion
