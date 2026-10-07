@tool
extends Area2D
class_name BattleHurtbox2D
#region 独立可编辑受击区域
@export var collision_path: NodePath = ^"CollisionShape2D"
@export var vulnerable: bool = true
@export var preview_color := Color(0.35, 0.65, 1.0, 0.15)

func _ready() -> void:
	set_process(Engine.is_editor_hint())

func _process(_delta: float) -> void:
	# 编辑形状、位置或 vulnerable 后，蓝色预览即时同步。
	queue_redraw()

func is_configuration_valid() -> bool:
	var collision := get_node_or_null(collision_path) as CollisionShape2D
	return collision != null and collision.shape is RectangleShape2D and collision.shape.size.x > 0.0 and collision.shape.size.y > 0.0

func get_polygon_global() -> PackedVector2Array:
	if not vulnerable or not is_configuration_valid():
		return PackedVector2Array()
	var collision := get_node(collision_path) as CollisionShape2D
	var rect := collision.shape.get_rect()
	return collision.global_transform * PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var points := global_transform.affine_inverse() * get_polygon_global()
	if points.is_empty():
		return
	draw_colored_polygon(points, preview_color)
	points.append(points[0])
	draw_polyline(points, Color(preview_color, 0.9), 1.5)
#endregion
