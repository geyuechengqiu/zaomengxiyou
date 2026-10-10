extends Resource
class_name BattleBossObjectDefinition
#region 时间轴场景对象只读定义
@export var object_id: StringName
@export_enum("projectile", "wall") var kind: String = "projectile"
@export var animation: StringName
@export var continuation_animation: StringName
@export var formation_seconds: float = 0.0
@export var lifetime: float = 1.0
@export var speed: float = 0.0
@export var spawn_offset: Vector2
@export var angles: Array[float] = [0.0]
@export var linked_to_action: bool = true
@export var through_targets: bool = false
@export var hit_interval: float = 0.1
## 原版DamageControl按count >= atkMax拦截；0禁用命中，正数为每对象/目标上限。
@export var maximum_hits: int = 1
@export var source_fps: float = 30.0
@export var hit_rects: Dictionary[int, Rect2] = {}
@export var continuation_rects: Dictionary[int, Rect2] = {}
@export var damage_context: Dictionary = {}

func is_valid() -> bool:
	if object_id.is_empty() or animation.is_empty() or angles.is_empty() or source_fps <= 0 or maximum_hits < 0 or not spawn_offset.is_finite(): return false
	for value in [formation_seconds, lifetime, speed, hit_interval, source_fps]:
		if not is_finite(value) or value < 0: return false
	for angle in angles:
		if not is_finite(angle): return false
	for rows in [hit_rects, continuation_rects]:
		for frame in rows:
			var rect: Rect2 = rows[frame]
			if frame < 0 or not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x <= 0 or rect.size.y <= 0: return false
	return lifetime > 0 and not hit_rects.is_empty()
#endregion
