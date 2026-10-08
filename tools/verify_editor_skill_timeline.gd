extends SceneTree
#region 编辑器真实攻击段资源预览
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	if not Engine.is_editor_hint():
		push_error("请使用 --editor --script res://tools/verify_editor_skill_timeline.gd")
		quit(1)
		return
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _verify() -> void:
	await create_timer(1.0).timeout
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	EditorInterface.open_scene_from_path("res://data/battle2d/skill_timeline/sunwukong_2d.tscn")
	for frame in range(5):
		await process_frame
	var actor := EditorInterface.get_edited_scene_root() as Node2D
	var box := actor.get_node("AnimationAdapter/AttackHitbox") as Node2D
	var visual := actor.get_node("AnimationAdapter") as Node2D
	var collision := box.get_node("CollisionShape2D") as CollisionShape2D
	var shape := collision.shape
	var definition: Resource = box.get("preview_abilities")[0]
	var timeline: Resource = definition.get("features")[1]
	var segments: Array = timeline.get("attack_segments")
	for index in range(segments.size()):
		box.set("preview_action", StringName("attack_%d" % (index + 1)))
		box.set("preview_time", 0.15)
		await process_frame
		_check(box.visible and box.get("hit_index") == index + 1, "编辑器选择分段资源：%d" % (index + 1))
		_check(collision.shape == shape and visual.get_children().filter(func(node): return node is Area2D).size() == 1, "三个段仍复用一个攻击框和形状")
		var expected: Rect2 = segments[index].get("hit_rect")
		expected = Rect2(expected.position * 2.0, expected.size * 2.0)
		_check((box.call("get_rect_local", actor, 1) as Rect2).is_equal_approx(expected), "分段技能矩形与编辑器显示一致")
	var segment: Resource = segments[0]
	var original: Rect2 = segment.get("hit_rect")
	segment.set("hit_rect", Rect2(20,-100,90,80))
	box.set("preview_action", &"attack_1")
	await process_frame
	_check(collision.shape.size == Vector2(180,160) and collision.position == Vector2(130,-120), "Inspector修改段矩形实时刷新同一形状")
	segment.set("hit_rect", original)
	await process_frame
	_check(collision.shape == shape and collision.shape.size.is_equal_approx(original.size * 2.0), "恢复预览数据不新增节点或污染保存资源")
	if failures.is_empty():
		print("PASS editor skill timeline: %d checks; segmented resources, one hitbox, Inspector geometry and restoration" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
#endregion
