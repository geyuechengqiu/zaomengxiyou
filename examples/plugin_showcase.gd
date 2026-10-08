extends Control
#region 类型与常量

const ExampleData = preload("res://addons/gameplay_abiltiy_system/examples/example_data.gd")
const BurnStatus = preload("res://addons/gameplay_abiltiy_system/examples/burn_status.tres")
const InventoryScene = preload("res://addons/simple_inventory/src/widgets/inventory.tscn")
const AbilityButtonScene = preload("res://addons/gameplay_abiltiy_system/ui/ability_button.tscn")
const EffectIcon = preload("res://addons/gameplay_abiltiy_system/assets/effect_icon.svg")
#endregion
#region 配置与运行状态

var target: Node3D
var vitals: GameplayVitalAttributeComponent
var statuses: GameplayStatusComponent
var abilities: GameplayAbilityComponent
var inventory: C_Inventory
var inventory_widget: InventoryWidget
var tabs: TabContainer
var health_bar: ProgressBar
var health_label: Label
var status_label: Label
var cooldown_label: Label
var heal_ability: GameplayAbilityInstance
var draw_enabled := true
#endregion
#region 生命周期与引擎回调

func _ready() -> void:
	ExampleData.register_tags()
	_create_components()
	_create_ui()
	_create_debug_camera()
	Panku.gd_exprenv.register_env("demo", self)
	print("插件演示已就绪：技能效果、状态、背包、控制台与调试绘制。")
#endregion
#region 内部实现

func _create_components() -> void:
	target = Node3D.new()
	target.name = "DemoTarget"
	target.add_to_group("Entities")
	add_child(target)
	vitals = GameplayVitalAttributeComponent.new()
	vitals.name = "GameplayVitalAttributeComponent"
	target.add_child(vitals)
	vitals.initialize(ExampleData.attribute_sets(), ExampleData.vitals())
	statuses = GameplayStatusComponent.new()
	statuses.name = "GameplayStatusComponent"
	target.add_child(statuses)
	abilities = GameplayAbilityComponent.new()
	abilities.name = "GameplayAbilityComponent"
	target.add_child(abilities)

	var heal := GE_ModifyVital.new()
	heal.vital_id = &"health"
	heal.amount = 25.0
	var cooldown := CooldownFeature.new()
	cooldown.cooldown_duration = 3.0
	var apply_effect := AbilityNodeApplyEffect.new()
	apply_effect.target_key = "target"
	apply_effect.effects = [heal]
	var sequence := BTSequence.new()
	sequence.children = [AbilityNodeCommitCooldown.new(), apply_effect]
	var definition := GameplayAbilityDefinition.new()
	definition.ability_id = &"demo_heal"
	definition.ability_name = "治疗演示"
	definition.icon = EffectIcon
	definition.features = [cooldown]
	definition.execution_tree = sequence
	abilities.learn_ability(definition)
	heal_ability = abilities.get_ability_instance(&"demo_heal")

	inventory = C_Inventory.new()
	inventory.name = "C_Inventory"
	add_child(inventory)
	add_demo_items()

func _create_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	_label(column, "插件效果演示", 28)
	_label(column, "选择页签体验各插件；所有演示使用独立示例数据。")
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)

	var gas := VBoxContainer.new()
	gas.name = "技能与状态"
	gas.add_theme_constant_override("separation", 16)
	tabs.add_child(gas)
	_label(gas, "伤害 · 治疗 · 技能冷却 · 状态叠加 · 标签过滤", 22)
	health_label = _label(gas, "")
	health_bar = ProgressBar.new()
	health_bar.custom_minimum_size = Vector2(0, 32)
	gas.add_child(health_bar)
	status_label = _label(gas, "")
	var buttons := HBoxContainer.new()
	gas.add_child(buttons)
	_button(buttons, "应用伤害", damage)
	_button(buttons, "叠加状态", add_status)
	_button(buttons, "移除状态", clear_status)
	_button(buttons, "切换无敌标签", toggle_immunity)
	_button(buttons, "重置", reset_demo)
	var ability_row := HBoxContainer.new()
	gas.add_child(ability_row)
	var ability_button := AbilityButtonScene.instantiate() as AbilityButton
	ability_row.add_child(ability_button)
	ability_button.setup(heal_ability)
	ability_button.pressed.connect(func(_instance: GameplayAbilityInstance) -> void: heal())
	cooldown_label = _label(ability_row, "点击图标治疗 25 点；冷却 3 秒。")
	_label(gas, "无敌标签会阻止伤害；状态最多叠加 5 层，10 秒后自动移除。")
	_button(gas, "打开控制台", open_console)

	var bag := VBoxContainer.new()
	bag.name = "背包"
	tabs.add_child(bag)
	_label(bag, "左键选择，右键装备或卸下；可筛选、整理和分解演示道具。")
	_button(bag, "添加演示道具", add_demo_items)
	inventory_widget = InventoryScene.instantiate() as InventoryWidget
	bag.add_child(inventory_widget)
	inventory_widget.initialize(inventory)
	inventory_widget.open()
	_button(bag, "显示背包", inventory_widget.open)

	var debug := VBoxContainer.new()
	debug.name = "调试绘制"
	tabs.add_child(debug)
	_label(debug, "DebugDraw：旋转线框、坐标轴和文字。", 22)
	_button(debug, "显示 / 隐藏绘制", func() -> void: draw_enabled = not draw_enabled)
	# 让主视口中的 3D 调试图形透过此页签显示。
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	var console := VBoxContainer.new()
	console.name = "控制台"
	tabs.add_child(console)
	_label(console, "Panku Console", 22)
	_label(console, "打开控制台，输入 demo.damage()、demo.heal() 或 demo.add_status()。")
	_button(console, "打开控制台", open_console)

func _create_debug_camera() -> void:
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(4, 3, 6)
	camera.look_at(Vector3.ZERO)
	camera.current = true
#endregion
#region 生命周期与引擎回调

func _process(_delta: float) -> void:
	if not is_instance_valid(vitals) or not is_instance_valid(health_bar):
		return
	var health := vitals.get_vital(&"health")
	health_bar.max_value = health.get_max_value()
	health_bar.value = health.current_value
	health_label.text = "生命值 %.0f / %.0f　无敌：%s" % [health.current_value, health.get_max_value(), "开启" if TagManager.has_tag(target, &"state.invulnerable") else "关闭"]
	var status := statuses.get_status(&"burn")
	status_label.text = "状态：%d 层 / 剩余 %.0f ms" % [status.stacks, status.remaining_duration * 1000.0] if is_instance_valid(status) else "状态：无"
	var cooldown := heal_ability.get_feature("CooldownFeature") as CooldownFeature
	cooldown_label.text = "治疗 25 点　冷却：%.0f ms" % (cooldown.get_cooldown_remaining(heal_ability) * 1000.0)
	if tabs.current_tab == 2 and draw_enabled:
		var rotation := Basis(Vector3.UP, Time.get_ticks_msec() / 1000.0)
		DebugDraw.draw_transformed_cube(Transform3D(rotation, Vector3.ZERO), Color.CORNFLOWER_BLUE)
		DebugDraw.draw_line_3d(Vector3.ZERO, Vector3(2, 0, 0), Color.RED)
		DebugDraw.draw_line_3d(Vector3.ZERO, Vector3(0, 2, 0), Color.GREEN)
		DebugDraw.draw_line_3d(Vector3.ZERO, Vector3(0, 0, 2), Color.BLUE)
		DebugDraw.set_text("plugin_demo", "DebugDraw demo: cube + XYZ axes")
#endregion
#region 公共接口

func damage() -> void:
	var effect := GE_ApplyDamage.new()
	effect.apply(target, target, {})

func heal() -> bool:
	if not abilities.can_activate_ability(&"demo_heal"):
		return false
	return abilities.try_activate_ability(&"demo_heal", {"instigator": target, "input_target": target})

func add_status() -> void:
	statuses.apply_status(BurnStatus, target, 1, {})

func clear_status() -> void:
	statuses.remove_status(&"burn")

func toggle_immunity() -> void:
	if TagManager.has_tag(target, &"state.invulnerable"):
		TagManager.remove_tag(target, &"state.invulnerable")
	else:
		TagManager.add_tag(target, &"state.invulnerable")

func reset_demo() -> void:
	clear_status()
	TagManager.clear_all_tags(target)
	target.remove_from_group("death")
	var health := vitals.get_vital(&"health")
	health.current_value = health.get_max_value()
	heal_ability.set_blackboard_var("CooldownFeature_" + CooldownFeature.KEY_COOLDOWN_TIMER, 0.0)

func add_demo_items() -> void:
	var sword := Equip.new()
	sword.name = "演示剑"
	sword.category = Item.ITEM_TYPE.EQUIPMENT
	sword.equip_type = Equip.EQUIP_TYPE.WEAPON
	sword.icon = preload("res://addons/simple_inventory/assets/textures/items/sword.tres")
	inventory.add_item(sword)
	for quantity in [3, 4]:
		var item := Item.new()
		item.name = "演示材料"
		item.category = Item.ITEM_TYPE.MATERIAL
		item.max_stack = 20
		item.quantity = quantity
		item.icon = preload("res://addons/simple_inventory/assets/textures/items/wood.tres")
		inventory.add_item(item)

func open_console() -> void:
	Panku.gd_exprenv.get_env("interactive_shell").set_unified_window_visibility(true)
	Panku.gd_exprenv.get_env("interactive_shell").open_window()
#endregion
#region 内部实现

func _label(parent: Node, text: String, font_size: int = 16) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
#endregion
