@tool
extends Node2D
class_name OriginalUIAnimation2D
#region 预置AnimationPlayer；编辑器可见，业务只调用播放/停止
signal completed
@export var clip: StringName
@onready var player: AnimationPlayer = $AnimationPlayer
var active: bool = false
var play_count: int = 0

func _ready() -> void:
	if Engine.is_editor_hint(): return
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	player.animation_finished.connect(_on_finished)
	stop_effect()

func play_effect() -> void:
	active = true
	visible = true
	play_count += 1
	player.stop()
	player.play(clip)
	player.advance(0)

func advance_effect(delta: float) -> void:
	if active and delta > 0: player.advance(delta)

func stop_effect() -> void:
	active = false
	visible = false
	if is_instance_valid(player): player.stop()

func _on_finished(_animation: StringName) -> void:
	stop_effect()
	completed.emit()
#endregion
