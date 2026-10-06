extends Node3D
#region 类型与常量

const ExampleData = preload("res://addons/gameplay_abiltiy_system/examples/example_data.gd")
#endregion
#region 配置与运行状态
@onready var vital_component: GameplayVitalAttributeComponent = $GameplayVitalAttributeComponent
#endregion
#region 生命周期与引擎回调

func _ready() -> void:
	vital_component.initialize(ExampleData.attribute_sets(), ExampleData.vitals())
	var health := vital_component.get_vital(&"health") as HealthVital
	assert(is_equal_approx(health.current_value, 100.0))
	vital_component.modify_vital(&"health", -20.0)
	assert(is_equal_approx(health.current_value, 80.0))
	# 直接验证插件联动，不引入业务衍生属性公式。
	vital_component.set_base_value(&"max_health", 150.0)
	assert(is_equal_approx(health.get_max_value(), 150.0))
	assert(is_equal_approx(health.current_value, 80.0))
	vital_component.modify_vital(&"mana", -30.0)
	var mana := vital_component.get_vital(&"mana")
	mana.process_regen(1.0)
	assert(is_equal_approx(mana.current_value, 55.0))
	var effect := GE_ApplyDamage.new()
	effect.apply(self, self, {})
	assert(is_equal_approx(health.current_value, 65.0))
	vital_component.set_base_value(&"defense", 10.0)
	effect.apply(self, self, {})
	assert(is_equal_approx(health.current_value, 55.0))
	print("✅ Vital 初始化、上限联动、恢复和内置伤害策略测试通过")
#endregion
