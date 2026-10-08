extends Resource
class_name BattleHitReactionProfile
## 目标规则：只读定义。伤害、硬直、位移与无敌效果不互相代替。

#region 霸体、无敌与目标抵抗
@export var armor_blocks_kinds: Array[StringName] = [&"normal"]
@export_range(0.0, 10.0) var armor_damage_multiplier: float = 1.0
@export var armor_blocks_displacement: bool = true
@export var invulnerable_blocks_reaction: bool = true
@export var invulnerable_blocks_displacement: bool = true
@export var invulnerable_blocks_status: bool = true
@export var invulnerable_blocks_protection: bool = true
@export var invulnerable_blocks_hit_stop: bool = true
## 护盾/纯动作攻击可以扣血为零但仍产生反应；闪避始终不视作命中。
@export var react_on_zero_damage: bool = true
@export_range(0.0, 1.0) var knockback_resistance: float = 0.0
@export_range(0.0, 1.0) var launch_resistance: float = 0.0
@export_range(0.0, 1.0) var stun_resistance: float = 0.0
#endregion
#region 倒地、落地与起身时间（战斗秒，独立于动画长度）
@export_range(0.0, 5.0) var hit_landing_seconds: float = 0.1
@export_range(0.0, 10.0) var knockdown_seconds: float = 0.65
@export_range(0.0, 5.0) var getup_seconds: float = 0.35
@export var getup_invulnerable: bool = false
#endregion
#region 公共接口

func is_valid() -> bool:
	for value in [armor_damage_multiplier, hit_landing_seconds, knockdown_seconds, getup_seconds]:
		if not is_finite(value) or value < 0.0:
			return false
	for value in [knockback_resistance, launch_resistance, stun_resistance]:
		if not is_finite(value) or value < 0.0 or value > 1.0:
			return false
	return true
#endregion
