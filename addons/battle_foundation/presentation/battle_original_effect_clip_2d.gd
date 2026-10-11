extends Node2D
class_name BattleOriginalEffectClip2D
#region 原素材帧动画；场景预置、只由公共战斗时钟推进
@onready var player: AnimationPlayer = $AnimationPlayer
var age: float = 0.0
var play_count: int = 0

func _ready() -> void:
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	clear_effect()

func play_effect() -> void:
	age = 0.0
	play_count += 1
	visible = true
	player.play(&"play")
	player.advance(0.0)

func advance_effect(delta: float) -> void:
	if not visible or delta <= 0.0: return
	age += delta
	player.advance(delta)
	var clip := player.get_animation(&"play")
	if clip.loop_mode == Animation.LOOP_NONE and age + 0.000000001 >= clip.length:
		clear_effect()

func clear_effect() -> void:
	if is_instance_valid(player): player.stop()
	age = 0.0
	visible = false
#endregion
