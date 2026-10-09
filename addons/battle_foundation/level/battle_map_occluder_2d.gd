@tool
extends Sprite2D
class_name BattleMapOccluder2D
#region 原版近景遮挡：玩家附近80×80源像素矩形进入后半透明
@export_range(0,1) var barrier_alpha: float = 0.5
@export_range(0,1) var barrier_out_alpha: float = 1.0
@export var trigger_factions: Array[StringName] = [&"player",&"ally"]
## 当前战斗使用2倍世界坐标，等价于原版(-40,-80,80,80)。
@export var actor_probe_rect := Rect2(-80,-160,160,160)

func refresh_occlusion(actors: Array) -> void:
	var obstructed := false
	var rect := get_rect()
	var polygon := global_transform*PackedVector2Array([rect.position,Vector2(rect.end.x,rect.position.y),rect.end,Vector2(rect.position.x,rect.end.y)])
	if polygon.is_empty(): return
	var bounds := Rect2(polygon[0],Vector2.ZERO)
	for point in polygon: bounds = bounds.expand(point)
	for actor in actors:
		if not is_instance_valid(actor) or not actor is BattleEntity2D or not trigger_factions.has(actor.faction_id): continue
		if bounds.intersects(Rect2(actor.global_position+actor_probe_rect.position,actor_probe_rect.size)):
			obstructed = true
			break
	self_modulate.a = barrier_alpha if obstructed else barrier_out_alpha
#endregion
