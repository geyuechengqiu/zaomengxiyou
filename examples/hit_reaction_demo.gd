extends "res://examples/original_damage_demo.gd"
## 阶段9场景只组合预置节点与配置，不承担伤害、保护或物理裁决。

#region 场景配置与只读运行显示
const TARGET_MODES := ["普通", "霸体·伤害50%", "无敌·阻止全部效果", "免伤·允许动作反应"]
var target_mode: int = 0

func _ready() -> void:
	super._ready()
	$HUD/ProtectionSettings/Column/LeftMaximum.value = dummies[0].protection.maximum
	$HUD/ProtectionSettings/Column/RightMaximum.value = dummies[1].protection.maximum
	$HUD/ProtectionSettings/Column/LeftMaximum.value_changed.connect(func(value): set_protection_maximum(0, int(value)))
	$HUD/ProtectionSettings/Column/RightMaximum.value_changed.connect(func(value): set_protection_maximum(1, int(value)))
	set_target_mode(0)

func set_sample(index: int) -> void:
	super.set_sample(index)
	for dummy in dummies:
		dummy.attributes.set_base_value(&"hpMax", 20000.0)
		if dummy.is_alive():
			(dummy.attributes.get_vital(&"health") as HealthVital).heal(20000.0)

func toggle_power() -> void:
	set_target_mode((target_mode + 1) % TARGET_MODES.size())

func set_target_mode(index: int) -> void:
	target_mode = index
	for dummy in dummies:
		dummy.super_armor = index == 1
		dummy.reaction_profile = dummy.reaction_profile.duplicate(true)
		dummy.reaction_profile.armor_blocks_kinds = [&"normal", &"heavy", &"launch"]
		dummy.reaction_profile.armor_damage_multiplier = 0.5 if index == 1 else 1.0
		dummy.reaction_profile.invulnerable_blocks_reaction = index != 3
		dummy.reaction_profile.invulnerable_blocks_displacement = index != 3
		if index in [2, 3]:
			dummy.damage_rules.set_source(&"stage9.invulnerable", {"immune": true})
		else:
			dummy.damage_rules.remove_source(&"stage9.invulnerable")
	$HUD/Panel/Column/Buttons/Power.text = "目标：" + TARGET_MODES[index]
	message.text = "连按 J 五连击：硬直 → 定距击退 → 浮空 → 落地倒地 → 起身；保护触发后清零计数。"

func set_protection_maximum(target_index: int, value: int) -> void:
	var target := dummies[target_index]
	target.protection_profile.maximum_override = maxi(1, value)
	target.protection.clear()
	assert(target.protection.configure(target, target.protection_profile), target.protection.last_error)
	# 程序修改与手动输入共用入口；无信号更新避免再次调用 value_changed。
	var field: SpinBox = $HUD/ProtectionSettings/Column/LeftMaximum if target_index == 0 else $HUD/ProtectionSettings/Column/RightMaximum
	field.set_value_no_signal(target.protection.maximum)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	info.text = "悟空 %s · 命中%d · %s\n左 %s 保护%d/%d · 右 %s 保护%d/%d" % [player.action_state.get_state_name(), total_hits, TARGET_MODES[target_mode], dummies[0].action_state.get_state_name(), dummies[0].protection.score, dummies[0].protection.maximum, dummies[1].action_state.get_state_name(), dummies[1].protection.score, dummies[1].protection.maximum]
#endregion
