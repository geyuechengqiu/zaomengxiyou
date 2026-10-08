extends Node2D
class_name BattleMonsterHealthBar2D
#region 原版血条配置与独立运行状态
@export var enabled: bool = true
@export var always_show: bool = false
@export var is_team: bool = false
@export var source_offset := Vector2(0, -100)
@export var unit_scale: float = 2.0
@onready var mask: Control = $Mask
@onready var trail: Sprite2D = $Trail
var current_health: float = 1.0
var maximum_health: float = 1.0
var mask_ratio: float = 1.0
var hide_remaining: float = -1.0
var _team_elapsed: float = 0.0
var _trail_tween: Tween
#endregion
#region 初始化、生命通知和原版提前返回
func configure(show_hp: bool, permanent: bool, team: bool, hp: float, maximum: float) -> void:
	_cancel_trail()
	hide_remaining = -1.0
	_team_elapsed = 0.0
	enabled = show_hp
	always_show = permanent
	is_team = team
	scale = Vector2.ONE * unit_scale
	set_health(hp, maximum, false)
	visible = enabled and always_show and current_health > 0.0

func set_health(hp: float, maximum: float, notify: bool = true) -> void:
	current_health = hp
	maximum_health = maxf(maximum, 0.000001)
	if current_health <= 0.0:
		mask_ratio = 0.0
		mask.size.x = 0.0
		visible = false
		hide_remaining = -1.0
		_cancel_trail()
		return
	if notify:
		show_health()
	else:
		mask_ratio = _display_ratio(current_health / maximum_health)
		mask.size.x = 63.0 * mask_ratio
		trail.scale.x = mask_ratio

func show_health() -> void:
	if not enabled or current_health <= 0.0:
		visible = false
		return
	visible = true
	var raw_ratio := current_health / maximum_health
	# 原版先显示，再比较未限幅比例；相同比例不刷新两秒定时器。
	if mask_ratio == raw_ratio:
		return
	mask_ratio = _display_ratio(raw_ratio)
	mask.size.x = 63.0 * mask_ratio
	_cancel_trail()
	_trail_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_trail_tween.tween_property(trail, ^"scale:x", mask_ratio, 0.6)
	_trail_tween.pause()
	if not is_team:
		hide_remaining = 2.0

func _display_ratio(raw_ratio: float) -> float:
	return clampf(raw_ratio, 0.04, 1.0) if raw_ratio > 0.0 else 0.0
#endregion
#region 战斗时钟、朝向和清理
func advance_bar(delta: float, facing: int) -> void:
	# 镜像偏移X，不镜像血条本身；保持从左向右的血量方向。
	position = Vector2(source_offset.x * facing, source_offset.y) * unit_scale
	if delta <= 0.0:
		return
	if _trail_tween != null and _trail_tween.is_valid():
		_trail_tween.custom_step(delta)
	if is_team and enabled and current_health > 0.0:
		_team_elapsed += delta
		if _team_elapsed >= 1.0:
			_team_elapsed = fmod(_team_elapsed, 1.0)
			show_health()
	if hide_remaining >= 0.0:
		hide_remaining = maxf(0.0, hide_remaining - delta)
		if hide_remaining <= 0.000000001:
			hide_remaining = -1.0
			if not always_show:
				visible = false

func _cancel_trail() -> void:
	if _trail_tween != null and _trail_tween.is_valid():
		_trail_tween.kill()
	_trail_tween = null

func _exit_tree() -> void:
	_cancel_trail()
#endregion
