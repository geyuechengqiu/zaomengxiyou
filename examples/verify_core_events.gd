extends Node
#region 测试类型与事件清单

## 状态有自己的上下文缓存；其中嵌套的字典/对象仍保留引用。
class CountEventEffect extends GameplayEffect:
	func _apply(_target: Node, _instigator: Node, context: Dictionary) -> void:
		context.probe.event_hits += 1

const GAS_EVENTS: Array[String] = [
	"ability_learned", "ability_forgotten", "ability_activated",
	"ability_completed", "ability_cancelled", "ability_button_pressed",
	"status_applied", "status_removed", "damage_received", "damage_applied",
]
#endregion
#region 测试运行状态

var _failed := false
var _events: Dictionary = {}
var _callbacks: Dictionary = {}
var _bus: Node
var _damage_info: DamageInfo
var _health: HealthVital
var _health_before_damage := 0.0
var _reduce_damage := false
var _native_damage_count := 0
var _death_seen := false
#endregion
#region 测试入口

func _ready() -> void:
	_check_resources("res://addons/gameplay_abiltiy_system")
	if _failed:
		get_tree().quit(1)
		return
	_bus = CoreSystem.event_bus
	_check(is_instance_valid(_bus), "CoreSystem.event_bus 必须可用")
	_check(not ProjectSettings.has_setting("autoload/AbilityEventBus"), "旧自动加载应已删除")
	_check(not FileAccess.file_exists("res://addons/gameplay_abiltiy_system/scripts/singletons/ability_event_bus.gd"), "旧总线脚本应已删除")
	if _failed:
		get_tree().quit(1)
		return
	for event_name in GAS_EVENTS:
		var callback := _record_event.bind(event_name)
		_callbacks[event_name] = callback
		_bus.subscribe(event_name, callback)
	_bus.subscribe("damage_received", _on_damage_received, CoreSystem.CoreEventBus.Priority.HIGH)
	_bus.enable_history = true
	_bus.clear_event_history()

	var demo = preload("res://examples/plugin_showcase.tscn").instantiate()
	add_child(demo)
	await get_tree().process_frame
	demo.abilities.set_process(false)
	demo.statuses.set_process(false)
	_health = demo.vitals.get_vital(&"health") as HealthVital
	_health.damage_received.connect(_on_native_damage_received)
	_health.health_depleted.connect(_on_health_depleted)
	_check(_last_context("ability_learned").get("ability_id") == &"demo_heal", "学习事件必须进入 Core 按名订阅")
	_check(_last_context("ability_learned").get("entity") == demo.target, "学习事件实体应保持不变")

	_test_damage(demo)
	_test_custom_events(demo)
	_test_ability_lifecycle(demo)
	_test_demo_features(demo)

	for event_name in GAS_EVENTS:
		_check(_events.has(event_name), "遗漏 GAS 发布事件：" + event_name)
		_bus.unsubscribe(event_name, _callbacks[event_name])
	_bus.unsubscribe("damage_received", _on_damage_received)
	var history: Array[Dictionary] = _bus.get_event_history()
	for event_name in GAS_EVENTS:
		_check(history.any(func(entry): return entry.event_name == event_name), "Core 历史缺少事件：" + event_name)
	_bus.enable_history = false
	_bus.clear_event_history()
	demo.clear_status()
	demo.queue_free()
	await get_tree().process_frame
	_check(_bus.event_pushed.get_connections().is_empty(), "销毁演示后应清理全部 GAS 总线监听")
	if not _failed:
		print("PASS: GAS 全部资源、10 类 Core 事件、同步减伤、共享上下文、自定义事件、多组件退订/重入、技能/冷却/状态/标签/背包")
	get_tree().quit(1 if _failed else 0)
#endregion
#region 伤害与自定义事件验证

func _test_damage(demo: Node) -> void:
	var shield := GameplayStatusData.new()
	shield.status_id = &"core_test_shield"
	shield.duration = -1.0
	var listener := FeatureEventListener.new()
	listener.trigger_on_events = [&"damage_received"]
	var mitigation := GE_ModifyIncomingDamage.new()
	mitigation.damage_multiplier = 0.5
	listener.event_triggered_effects = [mitigation]
	shield.features = [listener]
	demo.statuses.apply_status(shield, demo.target)
	_damage_info = DamageInfo.new(demo.target, null, 20.0)
	_damage_info.final_damage = 20.0
	_reduce_damage = true
	var damage := _health.apply_damage(_damage_info, demo.target)
	_reduce_damage = false
	_check(is_equal_approx(damage, 5.0), "GAS 状态减伤和 Core 按名订阅减伤都应先于扣血执行")
	_check(is_equal_approx(_health.current_value, 95.0), "20 × 0.5 × 0.5 应只扣 5 点生命")
	_check(is_equal_approx(_health_before_damage, 100.0), "受伤前监听必须同步发生在扣血之前")
	_check(_last_context("damage_received").get("damage_info") == _damage_info, "受伤前不能复制 DamageInfo")
	_check(_last_context("damage_applied").get("damage_info") == _damage_info, "受伤后必须传递同一个 DamageInfo")
	_check(_native_damage_count == 1, "HealthVital 本地信号仍应独立触发一次")
	demo.statuses.remove_status(shield.status_id)
	_damage_info.final_damage = 20.0
	_check(is_equal_approx(_health.apply_damage(_damage_info, demo.target), 20.0), "移除盾后必须停止减伤")
	_health.heal(100.0)
	mitigation.damage_multiplier = 0.0
	demo.statuses.apply_status(shield, demo.target)
	var applied_count: int = _events["damage_applied"].size()
	_damage_info.final_damage = 20.0
	_check(is_zero_approx(_health.apply_damage(_damage_info, demo.target)), "完全减伤应阻止扣血")
	_check(is_equal_approx(_health.current_value, 100.0), "完全减伤后生命应保持不变")
	_check(_events["damage_applied"].size() == applied_count, "零伤害不应新增伤害后事件")
	demo.statuses.remove_status(shield.status_id)
	_damage_info = null

func _test_custom_events(demo: Node) -> void:
	var config := GameplayStatusData.new()
	config.status_id = &"core_test_custom"
	config.duration = -1.0
	var listener := FeatureEventListener.new()
	listener.trigger_on_events = [&"host_custom_event"]
	listener.event_triggered_effects = [CountEventEffect.new()]
	config.features = [listener]
	demo.statuses.apply_status(config, demo.target)
	var second := GameplayStatusComponent.new()
	demo.target.add_child(second)
	second.set_process(false)
	second.apply_status(config, demo.target)
	var context := {"probe": {"event_hits": 0}}
	_bus.push_event("host_custom_event", [context], true)
	_check(context.probe.event_hits == 2, "自定义事件必须到达两个独立状态组件，且保留嵌套对象")
	_check(_bus.event_pushed.get_connections().size() == 2, "每个状态组件只能连接一次")
	demo.target.remove_child(second)
	_bus.push_event("host_custom_event", [context], true)
	_check(context.probe.event_hits == 3, "离树组件应停止接收事件")
	_check(_bus.event_pushed.get_connections().size() == 1, "离树必须退订")
	demo.target.add_child(second)
	_bus.push_event("host_custom_event", [context], true)
	_check(context.probe.event_hits == 5, "再次入树必须恢复监听且不重复连接")
	for payload in [[], [12], [context, 12]]:
		_bus.push_event("host_custom_event", payload, true)
	_check(context.probe.event_hits == 5, "非 GAS 参数形状不应传给状态效果")
	second.remove_status(config.status_id)
	second.free()
	_bus.subscribe("host_custom_event", _on_custom_context)
	_bus.push_event("host_custom_event", context, true)
	_check(context.probe.event_hits == 6, "Core 自动包装单个 Dictionary 的接口也应可用")
	_check(context.get("named_callback_seen", false), "Core 按名订阅必须收到原始字典")
	_bus.unsubscribe("host_custom_event", _on_custom_context)
	demo.statuses.remove_status(config.status_id)
	_bus.push_event("host_custom_event", [context], true)
	_check(context.probe.event_hits == 6, "移除状态必须停止其事件效果")
#endregion
#region 技能和既有演示回归

func _test_ability_lifecycle(demo: Node) -> void:
	var bar := AbilityBar.new()
	bar.button_scene = preload("res://addons/gameplay_abiltiy_system/ui/ability_button.tscn")
	demo.add_child(bar)
	bar.setup(demo.abilities)
	var button: AbilityButton = bar.get_child(0)
	button.pressed.emit(demo.heal_ability)
	_check(_last_context("ability_button_pressed").get("ability_id") == &"demo_heal", "技能栏事件必须进入 Core")
	_check(demo.heal(), "治疗技能应能激活")
	demo.heal_ability.update(0.01)
	_check(_last_context("ability_activated").get("entity") == demo.target, "激活事件实体应保持不变")
	_check(_last_context("ability_completed").get("ability_id") == &"demo_heal", "自然完成事件必须进入 Core")
	_check(not demo.heal(), "迁移后冷却仍应阻止施放")
	demo.heal_ability.update(3.1)
	_check(demo.heal(), "冷却结束应恢复施放")
	demo.abilities.cancel_ability(&"demo_heal")
	_check(_last_context("ability_cancelled").get("ability_id") == &"demo_heal", "取消事件必须进入 Core")
	bar.free()
	demo.abilities.forget_ability(&"demo_heal")
	_check(_last_context("ability_forgotten").get("entity") == demo.target, "遗忘事件必须进入 Core")

func _test_demo_features(demo: Node) -> void:
	demo.damage()
	_check(is_equal_approx(_health.current_value, 85.0), "普通伤害应正常运行")
	demo.toggle_immunity()
	demo.damage()
	_check(is_equal_approx(_health.current_value, 85.0), "无敌标签应继续过滤伤害")
	demo.toggle_immunity()
	for index in 6:
		demo.add_status()
	var status: GameplayStatusInstance = demo.statuses.get_status(&"burn")
	_check(status.stacks == 5, "状态叠加上限应保持")
	_check(TagManager.has_tag(demo.target, &"status.burn"), "状态应添加标签")
	demo.statuses._process(10.1)
	_check(not demo.statuses.has_status(&"burn"), "状态应按时到期")
	_check(not TagManager.has_tag(demo.target, &"status.burn"), "到期应清理标签")
	var sword: Equip = demo.inventory.get_item(0)
	demo.inventory.equip_item(sword)
	_check(demo.inventory.equip_slots["weapon"][1] == sword, "背包装备应正常运行")
	demo.inventory.unequip_item(sword)
	_check(demo.inventory.equip_slots["weapon"][1] == null, "卸装应正常运行")
	var lethal := DamageInfo.new(demo.target, null, 200.0)
	lethal.final_damage = 200.0
	_health.apply_damage(lethal, demo.target)
	_check(not _health.is_alive and _death_seen, "致命伤害仍应触发生命耗尽")
	_check(demo.target.is_in_group(HealthVital.DEATH_GROUP_NAME), "死亡分组应正常添加")
#endregion
#region 测试回调与资源检查

func _record_event(context: Dictionary, event_name: String) -> void:
	if not _events.has(event_name):
		_events[event_name] = []
	_events[event_name].append(context)

func _last_context(event_name: String) -> Dictionary:
	var records: Array = _events.get(event_name, [])
	return {} if records.is_empty() else records.back()

func _on_damage_received(context: Dictionary) -> void:
	_health_before_damage = _health.current_value
	if _reduce_damage:
		context.damage_info.final_damage *= 0.5

func _on_custom_context(context: Dictionary) -> void:
	context["named_callback_seen"] = true

func _on_native_damage_received(_info: DamageInfo) -> void:
	_native_damage_count += 1

func _on_health_depleted(_instigator: Node) -> void:
	_death_seen = true

func _check(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

func _check_resources(directory: String) -> void:
	for file in DirAccess.get_files_at(directory):
		if file.get_extension() in ["tscn", "tres", "gd"]:
			var resource := ResourceLoader.load(directory.path_join(file))
			_check(resource != null, "GAS 资源无法加载：" + directory.path_join(file))
			if resource is GDScript and not resource.source_code.contains("@abstract"):
				_check(resource.can_instantiate(), "GAS 脚本无法编译：" + file)
	for subdirectory in DirAccess.get_directories_at(directory):
		_check_resources(directory.path_join(subdirectory))
#endregion
