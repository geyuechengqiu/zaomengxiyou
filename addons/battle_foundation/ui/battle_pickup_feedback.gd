extends Control
class_name BattlePickupFeedback
#region 共享HUD预置绘制；原FlyItemEntity不旋转、不缩放、不改变透明度
@export var target_path: NodePath = ^"../BattleTools/BagButton"
@export var target_offset: Vector2 = Vector2(27, 29)
var flights: Array[Dictionary] = []

func play_pickup(screen_position: Vector2, texture: Texture2D, screen_size: Vector2) -> void:
	var target := get_node_or_null(target_path) as Control
	if target == null or texture == null: return
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var start := inverse * screen_position
	var end := inverse * (target.get_global_transform_with_canvas() * target_offset)
	flights.append({"from":start, "to":end, "position":start, "duration":maxf(start.distance_to(end) / 200.0, 0.0001), "age":0.0, "texture":texture, "size":screen_size})
	queue_redraw()

func _process(delta: float) -> void:
	advance_effects(delta)

func advance_effects(delta: float) -> void:
	if delta <= 0 or flights.is_empty(): return
	for index in range(flights.size()-1, -1, -1):
		var flight: Dictionary = flights[index]
		flight.age += delta
		var time := clampf(float(flight.age) / float(flight.duration), 0.0, 1.0)
		flight.position = Vector2(flight.from).lerp(flight.to, 1.0 - pow(1.0 - time, 3))
		if time >= 1.0: flights.remove_at(index)
	queue_redraw()

func clear_effects() -> void:
	flights.clear()
	queue_redraw()

func _draw() -> void:
	for flight: Dictionary in flights:
		draw_texture_rect(flight.texture, Rect2(Vector2(flight.position) - Vector2(flight.size) / 2.0, flight.size), false)
#endregion
