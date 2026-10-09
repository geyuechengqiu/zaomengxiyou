extends Node
class_name BattleCameraRig2D
#region 原版Camera2跟随参数与预置插件节点
@export var player_path: NodePath = ^"../Actors/SunWukong"
@export var camera_path: NodePath = ^"../../Camera2D"
@export var host_path: NodePath = ^"../../Camera2D/PhantomCameraHost"
@export_range(1,120,1) var source_fps: float = 30.0
@export_range(0.001,1,0.001) var initial_follow_weight: float = 1.0
@export_range(0.001,1,0.001) var region_follow_weight: float = 0.2
@onready var _player := get_node(player_path) as Node2D
@onready var _camera := get_node(camera_path) as Camera2D
@onready var _host := get_node(host_path) as BattlePhantomCameraHost
@onready var _anchor := $FollowTarget as Marker2D
@onready var _pcam := $PlayerCamera as PhantomCamera2D
var region_bounds: Rect2
var center: Vector2
var going_next: bool = false
var _ratchet_left: float
var _weight: float
var _configured: bool = false
#endregion
#region 首次定位、过区与原版左边界棘轮
func _ready() -> void:
	assert(_player != null and _camera != null and _host != null, "镜头、Host、跟随目标必须由场景预置")
	_host.set_interpolation_mode(PhantomCameraHost.InterpolationMode.MANUAL)
	_pcam.process_mode = Node.PROCESS_MODE_DISABLED

func set_region_bounds(bounds: Rect2, initial: bool = false) -> void:
	assert(bounds.size.x > 0 and bounds.size.y > 0 and bounds.position.is_finite() and bounds.size.is_finite())
	region_bounds = bounds
	if initial or not _configured:
		_configured = true
		going_next = false
		_weight = initial_follow_weight
		center = _clamp_target(_player.global_position, bounds.position.x)
		_anchor.global_position = center
		_pcam.teleport_position()
	else:
		# Camera2.gotoNextScreen(0.2)：保留当前画面，直到角色带镜头进入新区。
		_weight = region_follow_weight
		going_next = true
		_ratchet_left = center.x - _view_size().x/2.0
	_sync_limits()

func _view_size() -> Vector2:
	return _camera.get_viewport_rect().size / _pcam.zoom

func _clamp_target(position: Vector2, left: float) -> Vector2:
	var half := _view_size()/2.0
	# 区域窄于视口时居中，避免clampf的上下界倒置。
	var min_x := left+half.x
	var max_x := region_bounds.end.x-half.x
	var min_y := region_bounds.position.y+half.y
	var max_y := region_bounds.end.y-half.y
	return Vector2(clampf(position.x,min_x,max_x) if min_x <= max_x else (left+region_bounds.end.x)/2.0,
		clampf(position.y,min_y,max_y) if min_y <= max_y else region_bounds.get_center().y)

func _target() -> Vector2:
	var left := region_bounds.position.x
	if going_next:
		var desired_left := _player.global_position.x-_view_size().x/2.0
		if desired_left < left:
			_ratchet_left = maxf(_ratchet_left,desired_left)
			left = _ratchet_left
		else:
			going_next = false
	return _clamp_target(_player.global_position,left)

func _sync_limits() -> void:
	# 硬限界不能立即跳到新区域左缘，否则Camera2D会绕过原版插值瞬移。
	var visible_left := center.x-_view_size().x/2.0
	var limits: Array[int] = [floori(minf(region_bounds.position.x,visible_left)),floori(region_bounds.position.y),ceili(region_bounds.end.x),ceili(region_bounds.end.y)]
	# Host异步完成首次选镜之前也保持有效边界；位置只由插件写入。
	for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		if _pcam.get_limit(side) != limits[side]: _pcam.set_limit(side,limits[side])
		if _camera.get_limit(side) != limits[side]: _camera.set_limit(side,limits[side])
#endregion
#region 唯一战斗时钟入口
func advance_camera(delta: float) -> void:
	if not _configured or delta <= 0 or not is_instance_valid(_player): return
	if _player is BattleEntity2D and not (_player as BattleEntity2D).is_alive(): return
	var target := _target()
	# 与原30FPS lerp(old,target,weight)等价，60FPS/低FPS不改变固定目标的耗时。
	var alpha := 1.0-pow(1.0-_weight,source_fps*delta)
	center = center.lerp(target,alpha)
	_anchor.global_position = center
	_sync_limits()
	if is_instance_valid(_host.get_active_pcam()):
		_host.process(delta)
		_camera.force_update_scroll()

func stop() -> void:
	_configured = false
	going_next = false
#endregion
