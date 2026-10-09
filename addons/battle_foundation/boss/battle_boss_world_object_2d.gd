extends Node2D
class_name BattleBossWorldObject2D
#region 预置弹道/石墙；逐释放数据与碰撞互不共享
@export var definition: BattleBossObjectDefinition
@onready var player: AnimationPlayer = $AnimationPlayer
@onready var obstacle: StaticBody2D = $Obstacle
@onready var collision: CollisionShape2D = $Obstacle/CollisionShape2D
var active: bool = false
var attack_id: StringName
var age: float = 0.0
var spawn_tick: int = 0
var spawn_skill_time: float = 0.0
var last_advanced_tick: int = -1
var velocity: Vector2
var facing: int = 1
var attacker: WeakRef
var context: Dictionary = {}
var hits: Dictionary = {}
var _continuation: bool = false
var _geometry: Rect2

func _ready() -> void:
	top_level = true
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	release()

func activate(actor: BattleEntity2D, cast: BattleAttackInstance, angle: float, marker: Dictionary) -> void:
	assert(definition != null and definition.is_valid(), "场景对象定义无效")
	active = true
	visible = true
	attacker = weakref(actor)
	attack_id = cast.attack_id
	facing = cast.facing
	age = 0
	_continuation = false
	hits.clear()
	spawn_tick = actor.session.clock.physics_tick
	last_advanced_tick = -1
	spawn_skill_time = float(marker.skill_time)
	global_position = actor.global_position+Vector2(definition.spawn_offset.x*facing, definition.spawn_offset.y)*2
	var direction := Vector2(cos(deg_to_rad(angle))*facing, sin(deg_to_rad(angle)))
	velocity = direction*definition.speed*2
	rotation = direction.angle() if definition.kind == "projectile" else 0.0
	context = definition.damage_context.duplicate(true)
	context.merge({"ability_id": cast.ability_id, "attack_id": cast.attack_id, "skill_level": 1, "attack_facing": facing, "defer_attack_feedback": true, "object_id": definition.object_id}, true)
	collision.disabled = true
	player.stop()
	player.play(definition.animation)
	player.advance(0)
	_update_geometry()

func advance_object(delta: float) -> void:
	var actor := attacker.get_ref() as BattleEntity2D if attacker != null else null
	if not active or delta <= 0: return
	if not is_instance_valid(actor) or not actor.is_alive():
		release()
		return
	var remaining := minf(delta, definition.lifetime-age)
	# 固定源帧步长用于AB变化/持续命中，射线与目标扩展矩形仍做连续扫掠。
	while active and remaining > 0.00000001:
		var step := minf(remaining, 1.0/definition.source_fps)
		var before := global_position
		var after := before+velocity*step
		var terrain: Dictionary = {}
		if definition.kind == "projectile" and before != after:
			var query := PhysicsRayQueryParameters2D.create(before, after, 1, [actor.get_rid()])
			terrain = get_world_2d().direct_space_state.intersect_ray(query)
			if not terrain.is_empty(): after = terrain.position
		global_position = after
		age += step
		remaining -= step
		if not _continuation and not definition.continuation_animation.is_empty() and age+0.0000001 >= definition.formation_seconds:
			_continuation = true
			player.stop()
			player.play(definition.continuation_animation)
			player.advance(maxf(0, age-definition.formation_seconds))
		else: player.advance(step)
		_update_geometry()
		_sample_targets(actor, before, after)
		if not terrain.is_empty(): release()
		if age+0.0000001 >= definition.lifetime: release()

func _update_geometry() -> void:
	var rows := definition.continuation_rects if _continuation else definition.hit_rects
	var time := maxf(0, age-definition.formation_seconds) if _continuation else age
	var frame := floori(time*definition.source_fps)
	if _continuation and player.has_animation(definition.continuation_animation): frame %= maxi(1, roundi(player.get_animation(definition.continuation_animation).length*definition.source_fps))
	var chosen := -1
	for index in rows:
		if index <= frame and index > chosen: chosen = index
	if chosen < 0:
		_geometry = Rect2()
		return
	_geometry = Rect2(rows[chosen].position*2, rows[chosen].size*2)
	if definition.kind == "wall" and _continuation:
		(collision.shape as RectangleShape2D).size = _geometry.size
		collision.position = _geometry.get_center()
		collision.disabled = false

func _sample_targets(actor: BattleEntity2D, before: Vector2, after: Vector2) -> void:
	if _geometry.size == Vector2.ZERO: return
	var transformed := Transform2D(rotation, Vector2.ZERO)*_geometry
	for target in actor.session.get_entities():
		if not active or not actor.is_alive(): return
		if not target is BattleEntity2D or target == actor or not target.is_alive() or target.is_queued_for_deletion() or not actor.session.factions.is_hostile(actor.faction_id, target.faction_id): continue
		var polygon: PackedVector2Array = target.hurtbox.get_polygon_global()
		if polygon.is_empty(): continue
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon: bounds = bounds.expand(point)
		var half := transformed.size*0.5
		var expanded := Rect2(bounds.position-half, bounds.size+half*2)
		if not _crosses(expanded, before+transformed.get_center(), after+transformed.get_center()): continue
		var record: Dictionary = hits.get(target.entity_id, {"count": 0, "due": 0.0})
		if (definition.maximum_hits > 0 and record.count >= definition.maximum_hits) or age+0.0000001 < float(record.due): continue
		record.count += 1
		record.due = age+definition.hit_interval
		hits[target.entity_id] = record
		var payload := context.duplicate(true)
		payload["hit_index"] = get_index()+1
		payload["segment_id"] = definition.object_id
		payload["target_hit_count"] = record.count
		payload["skill_time"] = spawn_skill_time+age
		payload["sample_time"] = spawn_skill_time+age
		actor.resolve_attack_hit(target, payload)
		if not definition.through_targets: release()

func _crosses(rect: Rect2, from: Vector2, to: Vector2) -> bool:
	var low := 0.0
	var high := 1.0
	for axis in range(2):
		var diff: float = to[axis]-from[axis]
		if is_zero_approx(diff):
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]: return false
		else:
			var first: float = (rect.position[axis]-from[axis])/diff
			var last: float = (rect.end[axis]-from[axis])/diff
			low = maxf(low, minf(first,last))
			high = minf(high, maxf(first,last))
			if low > high: return false
	return true

func release() -> void:
	active = false
	visible = false
	attacker = null
	context.clear()
	hits.clear()
	velocity = Vector2.ZERO
	if is_instance_valid(collision): collision.disabled = true
	if is_instance_valid(player): player.stop()
#endregion
