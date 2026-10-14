extends SceneTree
#region 离线构建可保存的动画与命中框场景
const OUTPUT := "res://data/characters/sunwukong/animation/sunwukong_visual.tscn"
const ADAPTER = preload("res://addons/battle_foundation/animation/spine_animation_adapter.gd")

func _initialize() -> void:
	if FileAccess.file_exists(OUTPUT) and not OS.get_cmdline_user_args().has("--force"):
		print("Visual scene exists; preserve authored animations/hitboxes. Use --force only to rebuild explicitly.")
		quit()
		return
	# GAS/Core autoload 就绪后再加载依赖它们的技能和判定框脚本。
	call_deferred("_build")

func _build() -> void:
	var profile := load("res://data/characters/sunwukong/animation/sunwukong_profile.tres") as CharacterAnimationProfile
	var data := profile.skeleton_data as SpineSkeletonDataResource
	var visual := Node2D.new()
	visual.name = "AnimationAdapter"
	visual.set_script(ADAPTER)
	visual.set("profile", profile)
	var sprite := SpineSprite.new()
	sprite.name = "SpineVisual"
	sprite.scale = Vector2.ONE * profile.get_visual_scale()
	sprite.position = profile.skeleton_offset * profile.display_scale
	sprite.skeleton_data_res = data
	sprite.set("preview_skin", String(profile.base_skin))
	sprite.set("preview_animation", "idle")
	# 关闭静态帧预览，让 SpineAnimationTrack 跟随 AnimationPlayer 时间轴。
	sprite.set("preview_frame", false)
	sprite.set("preview_time", 0.0)
	visual.add_child(sprite)
	var track := SpineAnimationTrack.new()
	track.name = "SpineAnimationTrack"
	track.mix_duration = 0.0
	var nested := AnimationPlayer.new()
	nested.name = "SpineVisual Track 0"
	nested.add_animation_library(&"", _native_library(data))
	track.add_child(nested)
	sprite.add_child(track)
	var master := AnimationPlayer.new()
	master.name = "AnimationPlayer"
	master.add_animation_library(&"", _master_library(profile, data))
	visual.add_child(master)
	var armor := load("res://data/effects/super_armor/outline.tscn").instantiate()
	armor.get_node("Capture/Body").skeleton_data_res = data
	armor.get_node("Capture/Body").scale = Vector2.ONE / profile.skeleton_geometry_scale
	visual.add_child(armor)
	_add_hitbox(visual, profile.display_scale)
	_set_owners(visual, visual)
	var packed := PackedScene.new()
	assert(packed.pack(visual) == OK)
	assert(ResourceSaver.save(packed, OUTPUT) == OK)
	visual.free()
	print("Built static Spine + AnimationPlayer visual scene, semantic clips and one skill-driven hitbox.")
	quit()
#endregion
#region 与参考项目相同的原生播放器属性轨道
func _native_library(data: SpineSkeletonDataResource) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for source in data.get_animations():
		for loop in [false, true]:
			var clip := Animation.new()
			var name: StringName = StringName(source.get_name() + ("_looped" if loop else ""))
			clip.resource_name = name
			clip.length = source.get_duration()
			_value_track(clip, ^".:animation_name", source.get_name())
			_value_track(clip, ^".:loop", loop)
			library.add_animation(name, clip)
	var reset := Animation.new()
	reset.resource_name = "RESET"
	reset.length = 0.001
	_value_track(reset, ^".:animation_name", "")
	_value_track(reset, ^".:loop", false)
	library.add_animation(&"RESET", reset)
	return library

func _value_track(clip: Animation, path: NodePath, value: Variant) -> int:
	var index := clip.add_track(Animation.TYPE_VALUE)
	clip.track_set_path(index, path)
	clip.value_track_set_update_mode(index, Animation.UPDATE_DISCRETE)
	clip.track_insert_key(index, 0.0, value)
	return index
#endregion
#region 主播放器语义动作与命中框预览轨道
func _master_library(profile: CharacterAnimationProfile, data: SpineSkeletonDataResource) -> AnimationLibrary:
	var library := AnimationLibrary.new()
	for action in profile.animations:
		var native: StringName = profile.animations[action]
		var clip := Animation.new()
		clip.resource_name = action
		clip.length = (data.find_animation(String(native)) as SpineAnimation).get_duration()
		if profile.looping_actions.has(action):
			clip.loop_mode = Animation.LOOP_LINEAR
		var index := clip.add_track(Animation.TYPE_ANIMATION)
		clip.track_set_path(index, ^"SpineVisual/SpineAnimationTrack/SpineVisual Track 0")
		clip.track_insert_key(index, 0.0, String(native) + ("_looped" if profile.looping_actions.has(action) else ""))
		_value_track(clip, ^"AttackHitbox:preview_action", action)
		var time := _value_track(clip, ^"AttackHitbox:preview_time", 0.0)
		clip.value_track_set_update_mode(time, Animation.UPDATE_CONTINUOUS)
		clip.track_insert_key(time, clip.length, clip.length)
		library.add_animation(action, clip)
	return library
#endregion
#region 保存单一矩形，所有技能更新同一节点
func _add_hitbox(container: Node2D, scale: float) -> void:
	var script := load("res://addons/battle_foundation/movement/battle_hitbox_2d.gd") as Script
	var hitbox := script.new() as Area2D
	hitbox.name = "AttackHitbox"
	hitbox.set("source_unit_scale", scale)
	var preview: Array = hitbox.get("preview_abilities")
	for index in range(1, 6):
		preview.append(load("res://data/characters/sunwukong/skills/normal_attacks/attack%d.tres" % index))
	for path in ["res://data/characters/sunwukong/skills/normal_attacks/run_attack.tres", "res://data/characters/sunwukong/skills/normal_attacks/jump_attack.tres"]:
		if ResourceLoader.exists(path):
			preview.append(load(path))
	hitbox.collision_layer = 0
	hitbox.collision_mask = 0
	hitbox.monitoring = false
	hitbox.monitorable = false
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := RectangleShape2D.new()
	shape.resource_local_to_scene = true
	shape.size = Vector2.ONE
	collision.shape = shape
	collision.disabled = true
	hitbox.add_child(collision)
	container.add_child(hitbox)
	hitbox.call("configure_skill", preview[0])

func _set_owners(node: Node, scene: Node) -> void:
	for child in node.get_children():
		# SpineMesh2D 属于运行时内部绘制对象，不能序列化进可编辑场景。
		if child is SpineMesh2D:
			continue
		child.owner = scene
		_set_owners(child, scene)
#endregion
