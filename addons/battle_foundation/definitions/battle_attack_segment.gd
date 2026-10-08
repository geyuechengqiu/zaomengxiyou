@tool
extends Resource
class_name BattleAttackSegment
#region 独立攻击段定义（素材坐标，不保存运行状态）
@export var segment_id: StringName = &"hit_1"
@export var hit_index: int = 1
@export var start_frame: int = 4
## 半开窗口 [start_frame, end_frame)，相等表示瞬时攻击。
@export var end_frame: int = 6
@export var sub_skill_id: StringName = &""
@export var action: StringName = &"attack_1"
@export var hit_rect: Rect2 = Rect2(-114, -104.95, 267, 99.95)
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var damage_multiplier: float = 1.0
@export var fixed_damage: float = 0.0
## 0 表示每目标一次；正值允许重复命中，按战斗秒计时。
@export var hit_interval: float = 0.0
@export var maximum_hits: int = 1
## 反应速度使用 Godot 世界像素/秒；水平速度按攻击者朝向镜像。
@export var knockback_speed: float = 0.0
@export var knockback_duration: float = 0.0
@export var launch_speed: float = 0.0
## -1 沿用角色默认硬直；0 表示无额外硬直。
@export var hit_stun: float = -1.0
@export var interrupt_kind: StringName = &"normal"
@export var interrupt_priority: int = 60
@export var protection_value: float = 0.0
@export_enum("auto", "none", "hurt", "knockback", "launch", "knockdown") var reaction_type: String = "auto"
@export var knockdown: bool = false
@export_enum("speed", "displacement") var knockback_mode: String = "speed"
@export var knockback_distance: float = 0.0
@export_enum("attack_facing", "away_from_attacker", "target_facing", "explicit") var knockback_direction: String = "attack_facing"
@export_enum("Left:-1", "Right:1") var knockback_sign: int = 1
@export var hit_stop_seconds: float = 0.0
## 原技能 ID/合并计数键。参数为空时读取导入的原版技能表。
@export var protection_skill_id: String = ""
@export var protection_count_key: String = ""
@export var protection_parameters: Dictionary = {}
@export var status_ids: Array[StringName] = []
@export var has_hit_effect: bool = true
#endregion
#region 配置校验与兼容命中上下文
func is_valid(duration_frames: int) -> bool:
	if not is_finite(knockback_distance) or not is_finite(hit_stop_seconds) or hit_stop_seconds < 0.0 or (knockback_mode == "displacement" and knockback_distance != 0.0 and knockback_duration <= 0.0):
		return false
	return not segment_id.is_empty() and hit_index > 0 and start_frame >= 0 and end_frame >= start_frame and end_frame <= duration_frames and hit_rect.position.is_finite() and hit_rect.size.is_finite() and hit_rect.size.x > 0.0 and hit_rect.size.y > 0.0 and spawn_offset.is_finite() and is_finite(damage_multiplier) and damage_multiplier >= 0.0 and is_finite(fixed_damage) and fixed_damage >= 0.0 and is_finite(hit_interval) and hit_interval >= 0.0 and (hit_interval == 0.0 or hit_interval >= 0.001) and maximum_hits > 0 and is_finite(knockback_speed) and is_finite(knockback_duration) and knockback_duration >= 0.0 and is_finite(launch_speed) and launch_speed >= 0.0 and is_finite(hit_stun) and hit_stun >= -1.0 and is_finite(protection_value) and protection_value >= 0.0

func get_payload() -> Dictionary:
	return {"segment_id": segment_id, "hit_index": hit_index, "sub_skill_id": sub_skill_id, "action": action, "hit_rect": hit_rect, "hit_offset": spawn_offset, "hit_window_frames": end_frame - start_frame, "damage_multiplier": damage_multiplier, "fixed_damage": fixed_damage, "hit_interval": hit_interval, "maximum_hits": maximum_hits, "knockback_speed": knockback_speed, "knockback_duration": knockback_duration, "launch_speed": launch_speed, "hit_stun": hit_stun, "interrupt_kind": interrupt_kind, "interrupt_priority": interrupt_priority, "protection_value": protection_value, "status_ids": status_ids.duplicate(), "has_hit_effect": has_hit_effect, "reaction_type": StringName(reaction_type), "knockdown": knockdown, "knockback_mode": StringName(knockback_mode), "knockback_distance": knockback_distance, "knockback_direction": StringName(knockback_direction), "knockback_sign": knockback_sign, "hit_stop_seconds": hit_stop_seconds, "protection_skill_id": protection_skill_id, "protection_count_key": protection_count_key, "protection_parameters": protection_parameters.duplicate(true)}
#endregion
