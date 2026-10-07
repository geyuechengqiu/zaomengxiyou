extends Node3D
#region 类型与常量

const ExampleData = preload("res://addons/gameplay_abiltiy_system/examples/example_data.gd")
#endregion
#region 配置与运行状态
@onready var attribute_component: GameplayAttributeComponent = $GameplayAttributeComponent
#endregion
#region 生命周期与引擎回调


func _ready() -> void:
	attribute_component.initialize(ExampleData.attribute_sets())

	# 监听属性变化
	attribute_component.attribute_value_changed.connect(_on_attribute_changed)

	# 测试：打印所有属性值
	_print_all_attributes()

	# 测试修改属性值
	await get_tree().create_timer(1.0).timeout
	print("\n=== Modifying Strength ===")
	attribute_component.set_base_value(&"strength", 15.0)
	await get_tree().process_frame
	print("Strength: ", attribute_component.get_value(&"strength"))  # 应该输出 15

	# 测试 1：添加 ADD 修改器
	print("\n=== Test 1: Adding ADD Modifier (+10 Strength) ===")
	var modifier_add = GameplayAttributeModifier.new(
		&"strength",
		10,
		GameplayAttributeModifier.ModifierType.ADD
	)
	attribute_component.add_modifier(modifier_add)

	await get_tree().process_frame
	# 应该增加了 10
	print("Strength (with ADD modifier): ", attribute_component.get_value(&"strength"))  

	# 测试 2：添加 MULTIPLY 修改器
	print("\n=== Test 2: Adding MULTIPLY Modifier (+20% Strength) ===")
	var modifier_mult = GameplayAttributeModifier.new(
		&"strength",
		0.2,
		GameplayAttributeModifier.ModifierType.MULTIPLY
	)
	attribute_component.add_modifier(modifier_mult)
	
	await get_tree().process_frame
	# 应该是 (Base + 10) * 1.2
	print("Strength (with ADD + MULTIPLY): ", attribute_component.get_value(&"strength"))  
	
	# 测试 3：移除修改器
	print("\n=== Test 3: Removing Modifiers ===")
	attribute_component.remove_modifier(modifier_add)
	attribute_component.remove_modifier(modifier_mult)

	await get_tree().process_frame
	# 应该恢复原值
	print("Strength (after remove): ", attribute_component.get_value(&"strength"))  
#endregion
#region 信号回调

func _on_attribute_changed(id: StringName, new_val: float) -> void:
	print("Attribute %s changed to %f" % [id, new_val])
#endregion
#region 内部实现

func _print_all_attributes() -> void:
	print("=== Player Attributes ===")
	print("Strength: ", attribute_component.get_value(&"strength"))
	print("Agility: ", attribute_component.get_value(&"agility"))
	print("Intelligence: ", attribute_component.get_value(&"intelligence"))
	print("Vitality: ", attribute_component.get_value(&"vitality"))

	print("Max Health: ", attribute_component.get_value(&"hpMax"))
	print("Physical Attack: ", attribute_component.get_value(&"atk"))
	print("Defense: ", attribute_component.get_value(&"phyDef"))
#endregion
