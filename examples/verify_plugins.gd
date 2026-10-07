extends Node
#region 生命周期与引擎回调

## 验证插件资源和主要交互仍可独立运行；业务属性资源另有验证场景。
func _ready() -> void:
	assert(not DirAccess.dir_exists_absolute("res://scripts"))
	assert(not DirAccess.dir_exists_absolute("res://ui"))
	if not _check_resources("res://addons"):
		get_tree().quit(1)
		return
	var demo := preload("res://examples/plugin_showcase.tscn").instantiate()
	add_child(demo)
	await get_tree().process_frame
	var health: GameplayVital = demo.vitals.get_vital(&"health")
	demo.damage()
	assert(is_equal_approx(health.current_value, 85.0))
	demo.toggle_immunity()
	demo.damage()
	assert(is_equal_approx(health.current_value, 85.0), "无敌标签应拦截伤害")
	demo.toggle_immunity()
	demo.damage()
	assert(is_equal_approx(health.current_value, 70.0))
	assert(demo.heal())
	demo.heal_ability.update(0.01)
	assert(is_equal_approx(health.current_value, 95.0), "技能应应用治疗效果")
	assert(not demo.heal(), "冷却期间应阻止再次施放")
	demo.heal_ability.update(3.1)
	assert(demo.heal(), "冷却结束后应允许再次施放")
	demo.heal_ability.update(0.01)
	assert(is_equal_approx(health.current_value, 100.0))
	var modifier := GameplayEffectModifier.new()
	modifier.ability_id = &"demo_heal"
	modifier.damage_multiplier = 1.5
	modifier.duration_add = 2.0
	var modifier_feature := EffectModifierFeature.new()
	modifier_feature.effect_modifiers = [modifier]
	var context := {"damage_multiplier": 2.0, "duration_add": 1.0}
	modifier_feature.on_activate(demo.heal_ability, context)
	assert(is_equal_approx(context.damage_multiplier, 3.0))
	assert(is_equal_approx(context.duration_add, 3.0))
	for i in 6:
		demo.add_status()
	var status: GameplayStatusInstance = demo.statuses.get_status(&"burn")
	assert(status.stacks == 5)
	assert(TagManager.has_tag(demo.target, &"status.burn"))
	demo.statuses._process(10.1)
	assert(not demo.statuses.has_status(&"burn"))
	assert(not TagManager.has_tag(demo.target, &"status.burn"))
	demo.add_status()
	demo.clear_status()
	assert(not demo.statuses.has_status(&"burn"))

	var sword: Equip = demo.inventory.get_item(0)
	demo.inventory.equip_item(sword)
	assert(demo.inventory.equip_slots["weapon"][1] == sword)
	demo.inventory.unequip_item(sword)
	assert(demo.inventory.equip_slots["weapon"][1] == null)
	demo.inventory.pack_items()
	var material_count := 0
	for item: Item in demo.inventory.items:
		if item != null and item.category == Item.ITEM_TYPE.MATERIAL:
			material_count += 1
			assert(item.quantity == 7, "整理应合并两组演示材料")
	assert(material_count == 1)
	demo.inventory_widget._on_mouse_button_right_pressed(demo.inventory_widget.get_slot(19))
	for panel_path in ["status_debug_panel", "tag_debug_panel", "bt_debug_panel"]:
		var panel_scene := load("res://addons/gameplay_abiltiy_system/ui/%s.tscn" % panel_path) as PackedScene
		var panel := panel_scene.instantiate()
		add_child(panel)
		panel._unhandled_input(InputEventKey.new())
		panel.queue_free()
	demo.reset_demo()
	assert(is_equal_approx(health.current_value, 100.0))
	await get_tree().create_timer(0.2).timeout
	assert(Panku.gd_exprenv.get_env("demo") == demo)
	demo.open_console()
	for tab in 4:
		demo.tabs.current_tab = tab
		await get_tree().process_frame
	print("PASS: 插件资源、伤害/治疗、冷却、状态/标签、背包装备/整理、控制台和调试绘制")
	get_tree().quit()
#endregion
#region 内部实现

func _check_resources(directory: String) -> bool:
	for file in DirAccess.get_files_at(directory):
		if file.get_extension() in ["tscn", "tres", "gd"]:
			var resource := ResourceLoader.load(directory.path_join(file))
			if resource == null:
				push_error("资源无法独立加载：" + directory.path_join(file))
				return false
			if resource is GDScript and not resource.source_code.contains("@abstract"):
				if not resource.can_instantiate():
					push_error("脚本无法编译：" + directory.path_join(file))
					return false
	for subdirectory in DirAccess.get_directories_at(directory):
		if not _check_resources(directory.path_join(subdirectory)):
			return false
	return true
#endregion
