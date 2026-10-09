extends Node2D
class_name BattleBossObjectPool2D
#region 固定预置对象池，角色时间轴提出生成请求
var actor: BattleEntity2D
var spawn_count: int = 0

func bind(owner_actor: BattleEntity2D) -> void:
	actor = owner_actor
	for object in get_children():
		assert(object is BattleBossWorldObject2D and object.definition != null and object.definition.is_valid(), "Boss对象池需要预置完整对象场景")

func spawn_objects(marker: Dictionary, cast: BattleAttackInstance) -> void:
	var id := StringName(marker.get("object_id", &""))
	var available: Array[BattleBossWorldObject2D] = []
	for object in get_children():
		if object.definition.object_id == id and not object.active: available.append(object)
	if available.is_empty():
		actor.publish_battle_event(&"battle.boss.object_capacity_reached", {"object_id": id})
		return
	var cfg := available[0].definition
	if available.size() < cfg.angles.size():
		actor.publish_battle_event(&"battle.boss.object_capacity_reached", {"object_id": id})
		return
	for index in range(cfg.angles.size()):
		available[index].activate(actor, cast, cfg.angles[index], marker)
		spawn_count += 1
	actor.publish_battle_event(&"battle.boss.objects_spawned", {"object_id": id, "attack_id": cast.attack_id, "source_frame": marker.source_frame, "skill_time": marker.skill_time, "count": cfg.angles.size()})

func advance_objects(delta: float, before_skill_time: float, tick: int, ending_attack: StringName = &"") -> void:
	for object in get_children():
		if not object.active or object.last_advanced_tick == tick: continue
		if not ending_attack.is_empty() and (object.attack_id != ending_attack or not object.definition.linked_to_action): continue
		var step := delta
		if object.spawn_tick == tick: step = maxf(0, before_skill_time+delta-object.spawn_skill_time)
		object.last_advanced_tick = tick
		object.advance_object(step)

func release_attack(id: StringName, cancelled: bool) -> void:
	for object in get_children():
		if object.active and object.attack_id == id and (cancelled or object.definition.linked_to_action): object.release()

func clear_objects() -> void:
	for object in get_children(): object.release()
#endregion
