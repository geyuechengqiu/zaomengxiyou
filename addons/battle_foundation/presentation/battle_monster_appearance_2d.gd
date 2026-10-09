extends Node2D
class_name BattleMonsterAppearance2D
#region 原版showAppear；场景预置帧动画，战斗时钟驱动
@onready var player: AnimationPlayer = $AnimationPlayer
var play_count: int = 0

func _ready() -> void:
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	visible = false

func play_appearance(kind: int) -> float:
	clear_effect()
	var action := StringName("appear%d" % kind)
	if kind <= 0 or not player.has_animation(action): return 0.0
	play_count += 1
	visible = true
	player.play(action)
	player.advance(0.0)
	return player.get_animation(action).length

func advance_effect(delta: float) -> void:
	if visible and delta > 0.0: player.advance(delta)

func clear_effect() -> void:
	if is_instance_valid(player): player.stop()
	visible = false
#endregion
