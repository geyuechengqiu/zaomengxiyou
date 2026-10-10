extends Node
#region 测试入口与断言
const SCENE: PackedScene = preload("res://data/effects/damage_number.tscn")
var checks: int = 0
func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		push_error(message)
		get_tree().quit(1)
func _ready() -> void:
	var layer := BattleDamageNumberLayer2D.new()
	layer.number_scene = SCENE
	layer.prewarm_count = 3
	layer.max_cached_numbers = 3
	add_child(layer)
	_check(layer.get_active_count() == 0 and layer.get_pool_stats().cached == 3, "预热不产生有效跳字")
	_check(layer.get_child_count() == 3, "预热提前完成入树和ready")
	for row in layer.get_children():
		_check(not row.visible and row.finished and row.pool_index == -1, "预热缓存隐藏且不参与动画")
	var first := layer.spawn_number(SCENE, 123, "critical", Vector2(50, 100))
	var second := layer.spawn_number(SCENE, 456, "true", Vector2(80, 100))
	_check(layer.created_count == 3 and layer.reused_count == 2, "首次命中复用预热节点")
	layer.advance_numbers(0.475)
	_check(is_equal_approx(first.elapsed, 0.475) and is_equal_approx(second.elapsed, 0.475), "各实例只推进一次")
	var frozen := first.glyphs.position
	layer.advance_numbers(0.0)
	await get_tree().process_frame
	_check(first.glyphs.position == frozen and first.elapsed == 0.475, "暂停和SceneTree帧不改变曲线")
	first.advance_number(1.0)
	_check(layer.get_active_count() == 1 and not first.visible and first.get_parent() == layer, "回收保留隐藏节点且活动列表删除准确")
	first.rotation = 1.0
	first.scale = Vector2(2, 3)
	first.modulate = Color.RED
	var reused := layer.spawn_number(SCENE, 7, "heal", Vector2(12, 34))
	_check(reused == first, "复用同一个到期实例")
	_check(reused.number == 7 and reused.style == "heal" and reused.glyphs.number == 7 and reused.glyphs.style == "heal", "复用同步数值与样式")
	_check(reused.elapsed == 0.0 and not reused.finished and reused.visible and reused.position == Vector2(12, 34), "复用重置时间、完成状态和出生点")
	_check(reused.rotation == 0.0 and reused.scale == Vector2.ONE and reused.modulate == Color.WHITE, "复用重置根变换和调制")
	_check(reused.glyphs.position == Vector2.ZERO and reused.glyphs.scale == Vector2.ONE * 0.8 and reused.glyphs.modulate == Color.WHITE, "复用重置动画末帧属性")
	_check(layer.get_active_numbers() == [second, reused] and reused.spawn_order > second.spawn_order, "复用后按出生时间排列，不按旧树顺序")
	layer.advance_numbers(0.45)
	_check(second.finished and is_equal_approx(reused.elapsed, 0.45), "交换删除不会跳过或重复推进后生成实例")
	var late := layer.spawn_number(SCENE, 9, "dodge", Vector2.ZERO)
	layer.advance_numbers(0.45)
	_check(reused.finished and is_equal_approx(late.elapsed, 0.45), "边界到期与新实例时钟独立")
	layer.advance_numbers(1.0)
	_check(layer.get_active_count() == 0 and layer.get_pool_stats().cached == 3, "全部回收且缓存有界")
	var tweens_before := get_tree().get_processed_tweens().size()
	for index in range(500):
		layer.spawn_number(SCENE, index, "normal", Vector2.ZERO)
	_check(layer.get_active_count() == 500, "缓存上限不限制显示数量，不合并或丢弃命中")
	_check(get_tree().get_processed_tweens().size() == tweens_before, "大量实例不分配Tween或Tweener对象")
	layer.advance_numbers(1.5)
	_check(layer.get_active_count() == 0 and layer.get_pool_stats().cached == 3, "低帧率跨全部阶段清理500实例")
	await get_tree().process_frame
	_check(layer.get_child_count() == 3, "超过缓存上限的空闲节点确实释放")
	var external := layer.spawn_number(SCENE, 8, "normal", Vector2.ZERO)
	external.free()
	layer.advance_numbers(0.01)
	_check(layer.get_active_count() == 0, "外部删除实例不会污染活动列表")
	var old := layer.spawn_number(SCENE, 8, "normal", Vector2.ZERO)
	var old_id := old.get_instance_id()
	var alternative := SCENE.duplicate() as PackedScene
	var next := layer.spawn_number(alternative, 42, "true", Vector2.ZERO)
	old.advance_number(1.0)
	await get_tree().process_frame
	_check(not is_instance_id_valid(old_id) and next.visible and layer.get_active_count() == 1, "换场景释放旧缓存，旧活动实例正常结束但不进入新池")
	layer.clear_numbers()
	await get_tree().process_frame
	_check(layer.get_active_count() == 0 and layer.get_pool_stats().cached == 0 and layer.get_child_count() == 0, "主动清理释放全部活动与缓存")
	layer.prewarm(SCENE, 3)
	var cached_ids: Array[int] = []
	for row in layer.get_children():
		cached_ids.append(row.get_instance_id())
	layer.free()
	for instance_id in cached_ids:
		_check(not is_instance_id_valid(instance_id), "场景卸载无节点泄漏")
	_verify_atlas()
	print("PASS damage number pool: %d checks; warm/reuse/reset/order/pause/500 burst/bounded cache/scene generation/unload/shared atlas" % checks)
	get_tree().quit()
#endregion
#region 全部125别名保持原图尺寸和共享图集
func _verify_atlas() -> void:
	var library: BattleDamageNumberLibrary = load("res://data/effects/damage_number_textures.tres")
	var mapping: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/effects/damage_numbers/source_mapping.json"))
	var atlas: Texture2D = load("res://assets/effects/damage_numbers/atlas.png")
	var count := 0
	for group in library.groups.values():
		for texture: AtlasTexture in group:
			_check(texture.atlas == atlas and texture.filter_clip, "全部字形共享一个图集并防串色")
			count += 1
	_check(count == 125 and library.groups.size() == 15 and mapping.textures.size() == 125, "15组125原版贴图别名完整，新增原版回魔字形")
#endregion
