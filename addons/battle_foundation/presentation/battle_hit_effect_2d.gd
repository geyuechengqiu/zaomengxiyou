extends Node2D
class_name BattleHitEffect2D
#region 原版单次受击帧动画
@export var hit_offset := Vector2(0, -60)
@export var enabled: bool = true
@onready var player: AnimationPlayer = $AnimationPlayer
@onready var sprite: Sprite2D = $Sprite2D
var play_count: int = 0

func _ready() -> void:
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.animation_finished.connect(func(_action): visible = false)
	visible = false

func play_hit(facing: int, unit_scale: float) -> void:
	if not enabled:
		return
	# 原版镜像挂点 X；特效本身不随目标方向翻转。
	position = Vector2(hit_offset.x * facing, hit_offset.y) * unit_scale
	sprite.scale = Vector2.ONE * unit_scale
	visible = true
	play_count += 1
	# 连续命中重启本次闪光，不从上一击尚未结束的帧继续。
	player.stop()
	player.play(&"hit")
	player.advance(0.0)

func advance_effect(delta: float) -> void:
	if visible and delta > 0.0:
		player.advance(delta)
#endregion
