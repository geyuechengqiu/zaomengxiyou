@tool
extends Node2D
class_name BattleMapVisual2D
#region 预置视觉层：原生Parallax2D负责镜头，近景只按实体位置遮挡
@export var session_path: NodePath = ^"../../.."
@export var animated_player_paths: Array[NodePath] = []
var _session: BattleSession
var _players: Array[AnimationPlayer] = []
var _parallaxes: Array[Parallax2D] = []

func _ready() -> void:
	set_process(false)
	if not Engine.is_editor_hint(): _session = get_node_or_null(session_path) as BattleSession
	for path in [^"FarBackground",^"MiddleBackground",^"FixedMiddle"]:
		var layer := get_node(path) as Parallax2D
		_parallaxes.append(layer)
	if not Engine.is_editor_hint(): RenderingServer.frame_pre_draw.connect(refresh_view)
	for path in animated_player_paths:
		var player := get_node_or_null(path) as AnimationPlayer
		assert(player != null, "地图动画播放器必须预置")
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		_players.append(player)
		if not Engine.is_editor_hint() and not player.autoplay.is_empty():
			player.play(player.autoplay)
			player.advance(0)

func advance_visuals(delta: float) -> void:
	if delta > 0:
		for player in _players: player.advance(delta)
	refresh_view()

## Godot视差以镜头通知坐标为起点；原TMX以实际可见左上角为起点。
## 使用逻辑canvas变换，兼容缩放、镜头限界与窗口拉伸，不重复乘2。
func refresh_view() -> void:
	if Engine.is_editor_hint(): return
	var world_top_left := get_canvas_transform().affine_inverse()*Vector2.ZERO
	var local_top_left := global_transform.affine_inverse()*world_top_left
	for layer in _parallaxes:
		layer.screen_offset = local_top_left
	refresh_occlusion()

func _exit_tree() -> void:
	if RenderingServer.frame_pre_draw.is_connected(refresh_view): RenderingServer.frame_pre_draw.disconnect(refresh_view)

func refresh_occlusion() -> void:
	var actors: Array = _session.get_entities() if is_instance_valid(_session) else []
	for child in $ForegroundOccluders.get_children():
		if child is BattleMapOccluder2D: child.refresh_occlusion(actors)

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	for path in [^"FarBackground",^"MiddleBackground",^"FixedMiddle",^"GroundArtwork",^"ForegroundOccluders"]:
		if get_node_or_null(path) == null: warnings.append("视觉模板缺少层："+String(path))
	return warnings
#endregion
