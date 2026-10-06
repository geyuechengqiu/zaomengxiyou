extends Node3D
#region 配置与运行状态

@onready var player: Node3D = $Player
@onready var enemy: Node3D = $Enemy
@onready var player_vital_component: GameplayVitalAttributeComponent = $Player/GameplayVitalAttributeComponent
@onready var enemy_vital_component: GameplayVitalAttributeComponent = $Enemy/GameplayVitalAttributeComponent
#endregion
#region 类型与常量

const ExampleData = preload("res://addons/gameplay_abiltiy_system/examples/example_data.gd")
#endregion
#region 配置与运行状态
@export var damage_effect_res: GE_ApplyDamage = null
@export var heal_effect_res: GE_ModifyVital = null
#endregion
#region 生命周期与引擎回调

func _ready() -> void:
	player_vital_component.initialize(ExampleData.attribute_sets(), ExampleData.vitals())
	enemy_vital_component.initialize(ExampleData.attribute_sets(), ExampleData.vitals())
	ExampleData.register_tags()
	TagManager.add_tag(enemy, &"Team.Enemy")
	
	await get_tree().create_timer(0.5).timeout
	await _run_tests()
#endregion
#region 内部实现

func _run_tests() -> void:
	print("\n=== Day 15: Testing Basic Effects ===")

	# 测试 1：伤害效果
	await _test_damage_effect()
	await get_tree().create_timer(1.0).timeout

	# 测试 2：治疗效果
	await _test_heal_effect()
	await get_tree().create_timer(1.0).timeout

	print("\n=== Day 16: Testing Filter Functionality ===")

	# 测试 1：标签过滤（target_blocked_tags）
	await _test_tag_filter()
	await get_tree().create_timer(1.0).timeout
	await _test_filter_array()

## 测试 1：伤害效果
func _test_damage_effect() -> void:
	print("\n--- Test 1: Damage Effect ---")
	var health_vital = enemy_vital_component.get_vital(&"health")
	if not is_instance_valid(health_vital):
		return

	var initial_health = health_vital.current_value
	print("Enemy initial health: %.1f" % initial_health)

	# 创建上下文
	var context = {}
	context["instigator"] = player
	context["damage_multiplier_modifier"] = 2

	# 应用效果
	damage_effect_res.apply(enemy, player, context)
	await get_tree().process_frame

	var final_health = health_vital.current_value
	print("Enemy final health: %.1f" % final_health)

	assert(final_health < initial_health, "Damage effect test failed: Health should decrease")
	print("✅ Damage effect test passed: %.1f -> %.1f" % [initial_health, final_health])

## 测试 2：治疗效果
func _test_heal_effect() -> void:
	print("\n--- Test 2: Heal Effect ---")
	var health_vital = player_vital_component.get_vital(&"health")
	if not is_instance_valid(health_vital):
		return
		
	# 先扣血
	health_vital.modify_value(-30.0)
	var initial_health = health_vital.current_value
	print("Player initial health: %.1f" % initial_health)

	# 创建上下文
	var context = {}

	# 应用效果
	heal_effect_res.apply(player, player, context)
	await get_tree().process_frame

	var final_health = health_vital.current_value
	print("Player final health: %.1f" % final_health)

	assert(final_health > initial_health, "Heal effect test failed: Health should increase")
	print("✅ Heal effect test passed: %.1f -> %.1f" % [initial_health, final_health])

## 测试 3：标签过滤
func _test_tag_filter() -> void:
	print("\n--- Test 3: Tag Filter (target_blocked_tags) ---")
	
	var health_vital_enemy = enemy_vital_component.get_vital(&"health")
	if not is_instance_valid(health_vital_enemy):
		return
	
	var initial_health = health_vital_enemy.current_value
	print("Enemy initial health: %.1f" % initial_health)
	
	# 创建一个伤害效果，设置 target_blocked_tags
	var damage_effect = GE_ApplyDamage.new()
	damage_effect.damage_multiplier = 1.0
	damage_effect.vital_id = &"health"
	damage_effect.vital_comp_name = &"GameplayVitalAttributeComponent"
	damage_effect.target_blocked_tags = [&"state.invulnerable"] as Array[StringName]
	
	# 先测试：对正常敌人应用（应该生效）
	var context1 = {}
	context1["instigator"] = player
	damage_effect.apply(enemy, player, context1)
	await get_tree().process_frame
	
	var health_after_normal = health_vital_enemy.current_value
	print("Enemy health after normal damage: %.1f" % health_after_normal)
	
	# 验证：应该受到伤害
	assert(health_after_normal < initial_health, "Enemy should take damage")
	
	# 恢复血量
	var damage_taken = initial_health - health_after_normal
	health_vital_enemy.modify_value(damage_taken)
	
	# 给敌人添加免疫标签
	TagManager.add_tag(enemy, &"state.invulnerable")
	print("Added 'state.invulnerable' tag to enemy")
	
	# 再次应用伤害（应该被过滤）
	var context2 = {}
	context2["instigator"] = player
	damage_effect.apply(enemy, player, context2)
	await get_tree().process_frame
	
	var health_after_immune = health_vital_enemy.current_value
	print("Enemy health after immune damage: %.1f" % health_after_immune)
	
	# 验证：应该没有受到伤害（因为免疫）
	assert(abs(health_after_immune - initial_health) < 0.01, "Enemy should not take damage when immune")
	print("✅ Tag filter test passed: Immune target blocked damage")
	
	# 清理：移除免疫标签
	TagManager.remove_tag(enemy, &"state.invulnerable")

## 测试 4：过滤器数组（Day 16）
func _test_filter_array() -> void:
	print("\n--- Test 4: Filter Array ---")
	
	var health_vital_enemy = enemy_vital_component.get_vital(&"health")
	if not is_instance_valid(health_vital_enemy):
		return
	
	var initial_health = health_vital_enemy.current_value
	print("Enemy initial health: %.1f" % initial_health)
	
	# 创建一个过滤器：排除无敌目标
	var filter = FilterTargetByTags.new()
	filter.blocked_tags = [&"state.invulnerable"] as Array[StringName]
	
	# 创建伤害效果，使用过滤器数组
	var damage_effect = GE_ApplyDamage.new()
	damage_effect.damage_multiplier = 1.0
	damage_effect.vital_id = &"health"
	damage_effect.vital_comp_name = &"GameplayVitalAttributeComponent"
	damage_effect.filters.append(filter)
	
	# 给敌人添加免疫标签
	TagManager.add_tag(enemy, &"state.invulnerable")
	print("Added 'state.invulnerable' tag to enemy")
	
	# 应用伤害（应该被过滤器过滤）
	var context = {}
	context["instigator"] = player
	damage_effect.apply(enemy, player, context)
	await get_tree().process_frame
	
	var final_health = health_vital_enemy.current_value
	print("Enemy final health: %.1f" % final_health)
	
	# 验证：应该没有受到伤害（因为过滤器）
	assert(abs(final_health - initial_health) < 0.01, "Enemy should not take damage when filtered")
	print("✅ Filter array test passed: Filter blocked damage")
	
	# 清理：移除免疫标签
	TagManager.remove_tag(enemy, &"state.invulnerable")
#endregion
