extends Resource
class_name BattleProtectionProfile
## 每个 Boss 独立的 protectPoint 配置；绝不把当前条/命中次数写入 Resource。

#region 满值与原版数据来源
@export var enabled: bool = true
@export var show_protect: bool = true
@export var inherit_original_display: bool = true
@export var original_boss_key: String = "Monster/10001"
## -1 使用原版 Boss 表；正值覆盖，可在 Inspector 编辑，0 不合法。
@export var maximum_override: int = -1
@export_file("*.json") var original_data_path := "res://data/protection/original_protection.json"
@export var multiplayer_enemy: bool = false
@export_range(0.0, 10.0) var multiplayer_bonus: float = 0.8
@export var use_as_armor: bool = false
@export var inactivity_reset_seconds: float = 3.0
#endregion
#region 保护动作与明确的效果阻止策略
@export var protect_seconds: float = 0.8
@export var protection_action_enabled: bool = true
## 留空使用 Core PROTECT；非空时必须存在可激活的 GAS 技能，不偷偷降级。
@export var protect_ability_id: StringName = &""
@export var blocks_damage: bool = false
@export var blocks_reaction: bool = true
@export var blocks_displacement: bool = true
@export var blocks_status: bool = false
@export var counts_while_active: bool = false
#endregion

func is_valid() -> bool:
	return (maximum_override == -1 or maximum_override > 0) and is_finite(multiplayer_bonus) and multiplayer_bonus >= 0.0 and is_finite(inactivity_reset_seconds) and inactivity_reset_seconds >= 0.0 and is_finite(protect_seconds) and protect_seconds >= 0.0
