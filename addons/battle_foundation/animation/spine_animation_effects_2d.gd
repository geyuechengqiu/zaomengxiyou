@tool
extends Node2D
class_name SpineAnimationEffects2D
#region 仅编辑器使用的主时间轴快照
@export var animation_player_path: NodePath = ^"../AnimationPlayer"
@export var preview_action: StringName = &"idle":
	set(value):
		preview_action = value
		if Engine.is_editor_hint():
			_refresh_preview()
@export var preview_time: float = 0.0:
	set(value):
		preview_time = value
		if Engine.is_editor_hint():
			_refresh_preview()
#endregion
#region 编辑器前后拖动；游戏中由适配器和战斗时钟驱动
func _ready() -> void:
	# 原生子轨道先处理，快照最后提交，避免 seek 后新 TrackEntry 停在第0帧。
	process_priority = 100
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		_refresh_preview()

func _process(_delta: float) -> void:
	_refresh_preview()

func _refresh_preview() -> void:
	if not is_inside_tree():
		return
	var player := get_node_or_null(animation_player_path) as AnimationPlayer
	if player == null or not player.has_animation(preview_action):
		return
	var master := player.get_animation(preview_action)
	var root := player.get_node(player.root_node)
	for child in get_children():
		if not child is SpineSprite:
			continue
		var sprite := child as SpineSprite
		var nested := sprite.get_node_or_null("SpineAnimationTrack/AnimationPlayer") as AnimationPlayer
		if nested == null or sprite.get_skeleton_data_res() == null or not sprite.get_skeleton_data_res().is_skeleton_data_loaded():
			continue
		sprite.set_update_mode(SpineConstant.UpdateMode_Manual)
		nested.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		# 离散属性向后 seek 时可能保留最后一次写入；按保存的 key 重求可见性。
		sprite.visible = false
		for track in range(master.get_track_count()):
			var target := master.track_get_path(track)
			if not master.track_is_enabled(track) or master.track_get_type(track) != Animation.TYPE_VALUE or target.get_subname_count() != 1 or target.get_subname(0) != &"visible" or root.get_node_or_null(NodePath(target.get_concatenated_names())) != sprite:
				continue
			for key in range(master.track_get_key_count(track) - 1, -1, -1):
				if master.track_get_key_time(track, key) - preview_time <= 0.0000001:
					sprite.visible = bool(master.track_get_key_value(track, key))
					break
		if not SpineTimelinePose.apply(sprite, nested, master, root, preview_time, true):
			sprite.visible = false
			sprite.get_animation_state().clear_track(0)
#endregion
