@tool
extends Area2D
class_name BattleHitbox2D
#region 单一判定框与技能数据预览
## 编辑器只读技能定义；运行时使用实体 GAS 实例的独立定义。
@export var preview_abilities: Array[GameplayAbilityDefinition] = []
@export var source_unit_scale: float = 2.0
@export var collision_path: NodePath = ^"CollisionShape2D"
@export var editor_color: Color = Color(1.0, 0.65, 0.15, 0.18)
@export var preview_action: StringName = &"attack_1":
	set(value):
		preview_action = value
		if Engine.is_editor_hint():
			_refresh_preview()
@export var preview_time: float = 0.0:
	set(value):
		preview_time = value
		if Engine.is_editor_hint():
			_refresh_preview()
var ability_id: StringName
var action: StringName
var hit_index: int = 0
var _valid_geometry: bool = false
#endregion
#region 编辑器生命周期和数据选择
func _ready() -> void:
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		_refresh_preview()

func _process(_delta: float) -> void:
	# Inspector 修改技能 payload 后也能实时更新；不写回技能资源。
	_refresh_preview()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	var collision := get_node_or_null(collision_path) as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D:
		warnings.append("单一攻击框需要 CollisionShape2D / RectangleShape2D，几何由技能命中数据填充。")
	if not is_finite(source_unit_scale) or source_unit_scale <= 0.0:
		warnings.append("技能素材单位比例必须是有限正数。")
	return warnings

func is_configuration_valid() -> bool:
	return _get_configuration_warnings().is_empty()

func find_impact_payload(definition: GameplayAbilityDefinition, index: int) -> Dictionary:
	if definition != null:
		for feature in definition.features:
			if feature is BattleFrameTimelineFeature:
				for segment in feature.attack_segments:
					if segment != null and segment.hit_index == index:
						return segment.get_payload()
				for marker in feature.events:
					if marker != null and marker.event_id == &"battle.attack.impact" and int(marker.payload.get("hit_index", 1)) == index:
						return marker.payload
	return {}

func configure_skill(definition: GameplayAbilityDefinition, index: int = 1) -> bool:
	var payload := find_impact_payload(definition, index)
	if payload.is_empty() or not _apply_payload(payload):
		clear_geometry()
		return false
	if ability_id != definition.ability_id or hit_index != index or action != StringName(payload.get("action", &"")):
		queue_redraw()
	ability_id = definition.ability_id
	action = StringName(payload.get("action", &""))
	hit_index = index
	return true

func _refresh_preview() -> void:
	if not is_inside_tree():
		return
	for definition in preview_abilities:
		if definition == null:
			continue
		for feature in definition.features:
			if not feature is BattleFrameTimelineFeature:
				continue
			if not is_finite(feature.source_fps) or feature.source_fps <= 0.0:
				continue
			var chosen: BattleAttackSegment
			for segment in feature.attack_segments:
				if segment == null or segment.action != preview_action:
					continue
				if chosen == null or (segment.start_frame / feature.source_fps <= preview_time + 0.000000001 and segment.start_frame >= chosen.start_frame):
					chosen = segment
			if chosen != null:
				configure_skill(definition, chosen.hit_index)
				return
			var selected: BattleFrameEvent
			for marker in feature.events:
				if marker == null or marker.event_id != &"battle.attack.impact" or StringName(marker.payload.get("action", &"")) != preview_action:
					continue
				if selected == null or marker.source_frame / feature.source_fps <= preview_time + 0.000000001:
					selected = marker
			if selected != null:
				configure_skill(definition, int(selected.payload.get("hit_index", 1)))
				return
	clear_geometry()
#endregion
#region 从技能矩形、正缩放和偏移配置同一个形状
func _apply_payload(payload: Dictionary) -> bool:
	var collision := get_node_or_null(collision_path) as CollisionShape2D
	if collision == null or not collision.shape is RectangleShape2D or not payload.get("hit_rect") is Rect2:
		return false
	var rect: Rect2 = payload.hit_rect
	var scale_x: float = payload.get("hit_scale_x", 1.0)
	var scale_y: float = payload.get("hit_scale_y", 1.0)
	var offset: Vector2 = payload.get("hit_offset", Vector2.ZERO)
	if not is_finite(source_unit_scale) or source_unit_scale <= 0.0 or not is_finite(scale_x) or not is_finite(scale_y) or not offset.is_finite() or not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	# 原版负 scaleX 是显示镜像；只有正值缩放伤害框，朝向另行处理。
	var scales := Vector2(scale_x if scale_x > 0.0 else 1.0, scale_y if scale_y > 0.0 else 1.0)
	rect = Rect2((rect.position * scales + offset) * source_unit_scale, rect.size * scales * source_unit_scale)
	var changed: bool = not _valid_geometry or collision.position != rect.get_center() or collision.shape.size != rect.size or collision.rotation != 0.0 or collision.scale != Vector2.ONE or transform != Transform2D.IDENTITY
	if changed:
		transform = Transform2D.IDENTITY
		collision.transform = Transform2D(0.0, rect.get_center())
		collision.shape.size = rect.size
	_valid_geometry = true
	visible = true
	if changed:
		queue_redraw()
	return true

func clear_geometry() -> void:
	_valid_geometry = false
	ability_id = &""
	action = &""
	hit_index = 0
	visible = false
	queue_redraw()
#endregion
#region 可视化和同一份几何的实际命中
func _draw() -> void:
	if not Engine.is_editor_hint() or not _valid_geometry:
		return
	var polygon := get_polygon_local(self, 1)
	if polygon.is_empty():
		return
	draw_colored_polygon(polygon, editor_color)
	var outline := polygon.duplicate()
	outline.append(polygon[0])
	draw_polyline(outline, Color(editor_color, 0.95), 1.5)
	draw_string(ThemeDB.fallback_font, polygon[0] + Vector2(4, -5), "%s / hit %d" % [preview_action, hit_index], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(editor_color, 1.0))

func get_rect_local(owner_entity: Node2D, facing: int) -> Rect2:
	var polygon := get_polygon_local(owner_entity, facing)
	if polygon.is_empty():
		return Rect2()
	var rect := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		rect = rect.expand(point)
	return rect

func get_polygon_local(owner_entity: Node2D, facing: int) -> PackedVector2Array:
	var collision := get_node_or_null(collision_path) as CollisionShape2D
	if not _valid_geometry or collision == null or not collision.shape is RectangleShape2D:
		return PackedVector2Array()
	var rect := collision.shape.get_rect()
	var to_owner := owner_entity.global_transform.affine_inverse() * collision.global_transform
	var polygon := to_owner * PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	if facing < 0:
		for index in range(polygon.size()):
			polygon[index].x = -polygon[index].x
	return polygon

func intersects_hurtbox(owner_entity: Node2D, facing: int, hurtbox: BattleHurtbox2D) -> bool:
	var polygon := owner_entity.global_transform * get_polygon_local(owner_entity, facing)
	var target := hurtbox.get_polygon_global() if hurtbox != null else PackedVector2Array()
	return not polygon.is_empty() and not target.is_empty() and not Geometry2D.intersect_polygons(polygon, target).is_empty()
#endregion
