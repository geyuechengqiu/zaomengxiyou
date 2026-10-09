extends Node
#region 验收夹具与入口
const GAS_NODES := ["GameplayVitalAttributeComponent", "GameplayAbilityComponent", "GameplayStatusComponent", "DamageRules"]
const ACTION_NODES := ["ActionState", "MotionController", "ComboState", "HitReactionController", "ProtectionSystem"]
var checks: int = 0
var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _ready() -> void:
	_verify_packed_scenes()
	await _verify_binding_and_isolation()
	_verify_missing_components()
	if failures.is_empty():
		print("PASS character components: %d checks; authored scene nodes, binding without construction, nested variants, control ownership, runtime isolation, validation and disposal" % checks)
		get_tree().quit()
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)
#endregion
#region 入树前组件已经存在，场景实例只覆盖配置
func _verify_packed_scenes() -> void:
	for path in ["res://data/battle2d/sunwukong_2d.tscn", "res://data/battle2d/single_attack/sunwukong_2d.tscn", "res://data/battle2d/skill_timeline/sunwukong_2d.tscn", "res://data/battle2d/dummy/wooden_dummy.tscn", "res://data/battle/scenes/sample_entity.tscn"]:
		var actor: Node = load(path).instantiate()
		_check(actor.get_component_configuration_error().is_empty(), "角色场景在入树前具有完整组件：" + path)
		for name in GAS_NODES:
			_check(actor.get_node_or_null(NodePath(name)) != null, "预置GAS/伤害规则节点：" + name)
		if actor is BattleEntity2D:
			for name in ACTION_NODES:
				_check(actor.get_node_or_null(NodePath(name)) != null, "预置动作组件：" + name)
		if "sunwukong" in path:
			_check(actor.has_node("Inventory") and actor.has_node("PlayerOperations/OperationController"), "悟空及其变体预置背包和操作控制器")
			_check(not (actor.get_node("PlayerOperations") as BattlePlayerOperations).enabled, "角色模板默认让出玩家控制权")
		var machine: WeakRef = weakref(actor.get_node("ActionState").machine) if actor is BattleEntity2D else null
		actor.free()
		if machine != null:
			_check(machine.get_ref() == null, "未入树实例释放时也清理Core状态机循环引用")
	var arena: Node = load("res://examples/original_damage_demo.tscn").instantiate()
	_check((arena.get_node("BattleSession/Actors/SunWukong/PlayerOperations") as BattlePlayerOperations).enabled, "战斗样例在场景中开启玩家操作")
	for name in ["SunWukong", "LeftDummy", "RightDummy"]:
		var actor: Node = arena.get_node("BattleSession/Actors/" + name)
		for component_name in GAS_NODES:
			_check(actor.get_node(NodePath(component_name)).scene_file_path.is_empty(), "场景组件继承自角色，不新增另一份实例")
		_check(actor.get_child_count() == (15 if name == "SunWukong" else 12), "战斗场景未重复追加组件或产生自动命名后缀")
	arena.free()
#endregion
#region 绑定节点身份不变，各实体运行状态独立
func _verify_binding_and_isolation() -> void:
	var session := BattleSystem.create_session(self, "res://data/battle2d/manifest.json", 42)
	session.set_physics_process(false)
	var definition := session.catalog.instantiate_definition("characters", &"孙悟空") as BattleEntityDefinition
	var actor := definition.scene.instantiate() as BattleEntity2D
	var identities := {}
	for name in GAS_NODES + ACTION_NODES + ["Inventory", "PlayerOperations", "WushuangController"]:
		identities[name] = actor.get_node(NodePath(name)).get_instance_id()
	var count := actor.get_child_count()
	actor.initialize_battle(session, &"verification/authored", definition)
	session.add_child(actor)
	_check(actor.get_child_count() == count, "initialize与ready只绑定组件，不创建角色子节点")
	for name in identities:
		_check(actor.get_node(NodePath(name)).get_instance_id() == identities[name], "组件绑定保留场景节点身份：" + name)
	_check(actor.attributes == actor.get_node("GameplayVitalAttributeComponent") and actor.action_state == actor.get_node("ActionState") and actor.motion == actor.get_node("MotionController") and actor.combo == actor.get_node("ComboState"), "公共角色API使用预置节点")
	_check(actor.reactions == actor.get_node("HitReactionController") and actor.protection == actor.get_node("ProtectionSystem") and actor.damage_rules == (actor.get_node("DamageRules") as BattleDamageRulesComponent).rules, "受击、保护与伤害规则绑定正确")
	_check(actor.inventory == actor.get_node("Inventory") and actor.operations.controller == actor.get_node("PlayerOperations/OperationController"), "背包和Core输入控制器来自角色场景")
	var peer := session.spawn_entity_2d("characters", &"孙悟空")
	_check(actor.action_state != peer.action_state and actor.motion != peer.motion and actor.combo != peer.combo and actor.protection != peer.protection, "同配置角色动作组件独立")
	_check(actor.attributes.get_vital(&"health") != peer.attributes.get_vital(&"health") and actor.abilities.get_ability_instance(&"sunwukong_attack1") != peer.abilities.get_ability_instance(&"sunwukong_attack1"), "技能和Vital运行实例继续隔离")
	actor.damage_rules.grant_shield(&"verification", 100)
	actor.combo.turn_used = true
	actor.protection.score = 99
	actor.attributes.modify_vital(&"health", -10)
	_check(peer.damage_rules.get_shield_total() == 0 and not peer.combo.turn_used and peer.protection.score == 0 and peer.attributes.get_vital_value(&"health") == 275, "护盾、转身额度、保护与当前生命互不污染")
	_check(not actor.operations.controller.has_control() and not peer.operations.controller.has_control(), "预置多个悟空不会同时取得玩家控制权")
	actor.operations.enabled = true
	actor.operations.controller.pulse_intent(&"move_right")
	actor.operations.advance_simulation(1.0 / 60.0)
	_check(actor.operations.controller.has_control() and not peer.operations.controller.has_control() and peer.move_axis == 0, "启用玩家控制不影响测试目标")
	var id := actor.action_state.registration_id
	var input_id := actor.operations.controller.controller_id
	var machine: WeakRef = weakref(actor.action_state.machine)
	actor.free()
	_check(CoreSystem.state_machine_manager.get_state_machine(id) == null and CoreSystem.operation_manager.get_controller(input_id) == null and machine.get_ref() == null, "释放角色注销Core动作机、控制器及实例状态")
	session.free()
	await get_tree().process_frame
#endregion
#region 缺失组件被明确拒绝，不再补建
func _verify_missing_components() -> void:
	var actor := load("res://data/battle2d/sunwukong_2d.tscn").instantiate() as BattleEntity2D
	actor.get_node("GameplayAbilityComponent").free()
	var count := actor.get_child_count()
	_check("GameplayAbilityComponent" in actor.get_component_configuration_error() and actor.get_child_count() == count, "缺少GAS技能组件时返回配置错误，不自动补建")
	actor.free()
	actor = load("res://data/battle2d/sunwukong_2d.tscn").instantiate()
	actor.get_node("PlayerOperations/OperationController").free()
	_check("OperationController" in actor.get_component_configuration_error(), "缺少预置输入控制器时拒绝配置")
	actor.free()
	var session := BattleSystem.create_session(self, "res://data/battle2d/manifest.json", 0)
	session.set_physics_process(false)
	var definition := session.catalog.instantiate_definition("characters", &"孙悟空") as BattleEntityDefinition
	definition.scene = null
	session.catalog._definitions.characters[&"missing_scene"] = definition
	_check(session.spawn_entity_2d("characters", &"missing_scene") == null and "角色场景" in session.last_error and session.get_entities().is_empty(), "缺少角色场景不再使用动态空根节点工厂")
	session.free()
#endregion
