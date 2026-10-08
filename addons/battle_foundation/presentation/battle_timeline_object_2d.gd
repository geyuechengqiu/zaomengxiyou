extends Node2D
class_name BattleTimelineObject2D
#region 可预置的时间轴对象（不在启动或施放时创建节点）
@export_enum("effect", "projectile", "summon") var object_kind: String = "effect"
@export var lifetime: float = 0.3
var cast_id: StringName = &""
var remaining: float = 0.0
var velocity: Vector2 = Vector2.ZERO
var spawn_count: int = 0
var last_skill_time: float = 0.0

func _ready() -> void:
	visible = false

func activate_cast(attack: BattleAttackInstance, context: Dictionary, owner_entity: BattleEntity2D) -> void:
	cast_id = attack.attack_id
	last_skill_time = float(context.get("skill_time", attack.elapsed))
	top_level = object_kind != "effect"
	remaining = maxf(0.0, float(context.get("lifetime", lifetime)))
	var offset: Vector2 = context.get("spawn_offset", Vector2.ZERO)
	offset.x *= attack.facing
	global_position = owner_entity.global_position + offset
	velocity = context.get("velocity", Vector2.ZERO)
	velocity.x *= attack.facing
	spawn_count += 1
	visible = true
	var player := get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if player != null:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.stop()
		player.play(StringName(context.get("animation", &"play")))
		player.advance(0.0)
	attack.track_object(self)

func advance_object(delta: float) -> void:
	if not visible or delta <= 0.0:
		return
	var active_delta := minf(delta, remaining)
	global_position += velocity * active_delta
	var player := get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if player != null:
		player.advance(active_delta)
	remaining = maxf(0.0, remaining - delta)
	if remaining <= 0.0:
		release_cast(cast_id)

func release_cast(id: StringName) -> void:
	if cast_id != id:
		return
	cast_id = &""
	remaining = 0.0
	velocity = Vector2.ZERO
	visible = false
	var player := get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if player != null:
		player.stop()
#endregion
