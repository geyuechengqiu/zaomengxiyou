extends Node
#region 验收状态与入口
var checks: int = 0
var failures: Array[String] = []
var demo: Node2D
var session: BattleSession
var player: BattleEntity2D

func _ready() -> void:
	_verify_static_scene()
	demo = (load("res://examples/wukong_platform_demo.tscn") as PackedScene).instantiate()
	demo.enable_player_controls = false
	add_child(demo)
	demo.set_physics_process(false)
	session = demo.session
	session.set_physics_process(false)
	player = demo.player
	await _steps(8)
	_verify_skill_geometry()
	await _verify_real_damage()
	session.clear_battle()
	demo.queue_free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS animation authoring: %d checks; static players, one hitbox/shape, skill data geometry, invalid-data clearing, instance isolation and real GAS damage" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _steps(count: int) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		session.advance_physics(1.0 / 60.0)
#endregion
#region 预置播放器和单一判定框
func _verify_static_scene() -> void:
	var visual := (load("res://data/animation/sunwukong_visual.tscn") as PackedScene).instantiate() as SpineAnimationAdapter
	var master := visual.get_node("AnimationPlayer") as AnimationPlayer
	var track := visual.get_node("SpineVisual/SpineAnimationTrack") as SpineAnimationTrack
	var nested := track.get_child(0) as AnimationPlayer
	var box := visual.get_node("AttackHitbox") as BattleHitbox2D
	_check(track.get_child_count() == 1 and nested != null, "进入场景树前就存在原生轨道播放器")
	_check(visual.get_children().filter(func(node): return node is BattleHitbox2D).size() == 1 and box.get_child_count() == 1 and box.is_configuration_valid(), "场景只保存一个攻击框和一个形状")
	_check(box.preview_abilities.size() == 5, "编辑器引用技能数据而不是保存多套形状")
	_check(master.get_animation_list().size() == 14, "主播放器保存全部十四个语义动作")
	for action in visual.profile.animations:
		var clip := master.get_animation(action)
		var source: String = visual.profile.animations[action]
		_check(clip.track_get_type(0) == Animation.TYPE_ANIMATION and visual.get_node(clip.track_get_path(0)) == nested, "主动画通过原生子播放器选择动作：" + String(action))
		var native: String = clip.track_get_key_value(0, 0)
		_check(native == source + ("_looped" if visual.profile.looping_actions.has(action) else "") and nested.has_animation(native), "原生动作轨道存在且循环映射正确：" + String(action))
		_check(clip.length > 0.0, "主时间轴保存可编辑的语义动作时长：" + String(action))
	add_child(visual)
	_check(track.get_child_count() == 1 and track.get_child(0) == nested and visual.get_animation_player() == master, "运行时复用预置播放器，没有额外创建")
	_check(visual.last_error.is_empty(), "预置动画适配器初始化成功")
	visual.play_action(&"attack_4", true)
	visual.advance_animation(0.3)
	_check(box.preview_action == &"attack_4" and is_equal_approx(box.preview_time, 0.3), "主播放器仅传递预览动作与时间，命中帧来自技能")
	visual.free()
#endregion
#region 每次查询从实体技能定义更新同一形状
func _verify_skill_geometry() -> void:
	var box := player.attack_hitbox
	var collision := box.get_node("CollisionShape2D") as CollisionShape2D
	var shape := collision.shape
	var other_collision := demo.right_target.attack_hitbox.get_node("CollisionShape2D") as CollisionShape2D
	_check(shape != other_collision.shape and shape.resource_local_to_scene, "角色实例的形状独立，更新不会影响另一个角色")
	var definition := player.abilities.get_ability_instance(&"sunwukong_attack1").get_definition()
	var timeline := definition.features[1] as BattleFrameTimelineFeature
	var marker := timeline.events[0]
	var original := marker.payload.duplicate(true)
	marker.payload["hit_rect"] = Rect2(50, -65, 30, 40)
	var context := {"ability_id": &"sunwukong_attack1", "hit_index": 1, "hit_rect": Rect2(-999, -999, 9999, 9999)}
	player.animation.set_facing(1)
	_check(player.get_attack_rect_local(context).is_equal_approx(Rect2(100, -130, 60, 80)), "读取 GAS 实例技能数据，事件载荷不能覆盖技能定义")
	player.animation.set_facing(-1)
	_check(player.get_attack_rect_local(context).is_equal_approx(Rect2(-160, -130, 60, 80)), "技能数据更新后的范围按脚底完整镜像")
	player.animation.set_facing(1)
	marker.payload["hit_scale_x"] = 2.0
	marker.payload["hit_scale_y"] = 3.0
	marker.payload["hit_offset"] = Vector2(4, -2)
	_check(player.get_attack_rect_local(context).is_equal_approx(Rect2(208, -394, 120, 240)), "先正缩放，再偏移，最后转换素材单位")
	marker.payload["hit_scale_x"] = -1.0
	marker.payload["hit_scale_y"] = 1.0
	marker.payload["hit_offset"] = Vector2.ZERO
	_check(player.get_attack_rect_local(context).is_equal_approx(Rect2(100, -130, 60, 80)), "负显示缩放不能重复镜像伤害框")
	collision.position = Vector2(999, 999)
	collision.shape.size = Vector2(9999, 9999)
	_check(player.get_attack_rect_local(context).is_equal_approx(Rect2(100, -130, 60, 80)), "直接改形状不会覆盖技能数据，下次查询自动恢复")
	_check(other_collision.shape.size.is_equal_approx(Vector2(534, 199.9)), "当前角色技能修改与形状更新不影响另一个角色")
	_check((load("res://data/battle2d/attack1.tres") as GameplayAbilityDefinition).features[1].events[0].payload == original, "私有 GAS 定义修改不写回共享技能资源")
	marker.payload = original
	for index in range(1, 6):
		var id := StringName("sunwukong_attack%d" % index)
		_check(player.get_attack_rect_local({"ability_id": id}).has_area(), "所有技能都能驱动统一判定框")
		_check(player.attack_hitbox == box and collision.shape == shape and box.get_child_count() == 1, "切换技能不创建或替换节点与形状")
	var first := player.get_attack_rect_local({"ability_id": &"sunwukong_attack4", "hit_index": 1})
	var second := player.get_attack_rect_local({"ability_id": &"sunwukong_attack4", "hit_index": 2})
	_check(second.position.is_equal_approx(first.position + Vector2(-34, -8)) and second.size.is_equal_approx(first.size), "第四段双击更新同一框，偏移只应用一次")
	_check(player.get_attack_rect_local({"ability_id": &"sunwukong_attack4", "hit_index": 99}) == Rect2() and not box.visible, "缺少命中数据时清理形状有效性，不沿用上一击")
	marker.payload["hit_rect"] = Rect2(0, 0, -1, 10)
	_check(player.get_attack_rect_local(context) == Rect2(), "无效矩形不能造成上一击范围残留")
	marker.payload = original
#endregion
#region 修改技能数据后真实 GAS 伤害使用新范围
func _verify_real_damage() -> void:
	var target: BattleEntity2D = demo.right_target
	var definition := player.abilities.get_ability_instance(&"sunwukong_attack1").get_definition()
	var marker := (definition.features[1] as BattleFrameTimelineFeature).events[0]
	var original := marker.payload.duplicate(true)
	player.global_position = Vector2(350, 648)
	target.global_position = Vector2(600, 648)
	player.animation.set_facing(1)
	marker.payload["hit_rect"] = Rect2(30, -70, 10, 50)
	var before := target.attributes.get_vital_value(&"health")
	_check(player.request_attack(), "修改技能判定不影响激活")
	await _steps(25)
	_check(target.attributes.get_vital_value(&"health") == before, "缩小技能矩形后远处目标不再命中")
	marker.payload["hit_rect"] = Rect2(120, -70, 10, 50)
	_check(player.request_attack(), "更新同一个技能的矩形后再次施放")
	await _steps(25)
	_check(target.attributes.get_vital_value(&"health") < before, "同一个攻击框使用新的技能数据造成真实伤害")
	marker.payload = original
#endregion
