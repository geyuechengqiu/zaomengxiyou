extends Node2D
class_name BattleLootManager2D
#region 场景预置的公共掉落服务；灵魂飞行只负责表现，不再次发奖
@export var rules: JSON
@export var spirit_texture: Texture2D
## 原mission2 qualitybg按品质索引，保留源注册点，不对帧序列循环。
@export var quality_glows: Array[Texture2D] = []
@export var quality_glow_pivots: Array[Vector2] = []
## 扩展物品可直接拖入.tres定义；同ID覆盖JSON生成的默认定义。
@export var item_definitions: Array[Item] = []
@export_range(0.1, 10.0) var source_unit_scale: float = 2.0
@export_range(0.0, 600.0) var pickup_radius: float = 10.0
@export_range(1.0, 3600.0) var drop_lifetime: float = 180.0
var session: BattleSession
var catalog := OriginalItemCatalog.new()
var drops: Array[Dictionary] = []
var souls: Array[Dictionary] = []
var awarded: Dictionary = {}
var _pending: Dictionary = {}
var _monster_ids: Dictionary = {}
var _accumulator: float = 0.0
var _pickup_geometry := BattleLootPickupGeometry.new()
const SOURCE_STEP := 1.0 / 30.0

func _ready() -> void:
	session = get_parent() as BattleSession
	assert(session != null and rules != null, "掉落服务需要BattleSession与原版规则")
	catalog.configure(rules.data.items)
	for item in item_definitions:
		assert(item != null and not item.item_id.is_empty() and item.runtime == null, "掉落目录只能保存有效只读物品定义")
		catalog.definitions[item.item_id] = item
	for id in session.catalog.get_ids("monsters"):
		var definition := session.catalog.instantiate_definition("monsters", id)
		_monster_ids[id] = str(definition.get_meta(&"original_monster_id", String(id)))
	CoreSystem.event_bus.event_pushed.connect(_on_event)

func _exit_tree() -> void:
	if CoreSystem.event_bus.event_pushed.is_connected(_on_event): CoreSystem.event_bus.event_pushed.disconnect(_on_event)

func _on_event(id: String, payload: Array) -> void:
	if id not in ["battle.entity_died", "battle.entity.killed"] or payload.size() != 1 or not payload[0] is Dictionary: return
	var data: Dictionary = payload[0]
	if data.get("battle_id") != session.battle_id: return
	var dead_id: StringName = data.get("source_entity_id", &"") if id == "battle.entity_died" else data.get("target_entity_id", &"")
	var dead := session.get_entity(dead_id) as BattleEntity2D
	if dead == null or dead.faction_id != &"enemy" or not _monster_ids.has(dead.definition_id) or awarded.has(dead_id): return
	if not _pending.has(dead_id): _pending[dead_id] = {"monster": dead, "position": dead.global_position, "killer": null}
	if id == "battle.entity.killed": _pending[dead_id].killer = session.get_entity(data.get("source_entity_id", &""))

func advance_loot(delta: float) -> void:
	if session.clock.paused or (is_inside_tree() and get_tree().paused): return
	# 伤害、击杀被动全部处理后结算；直接修改生命死亡也使用同一入口。
	for id in _pending.keys():
		var entry: Dictionary = _pending[id]
		var player := _get_recipient(entry)
		if player != null: _award(id, entry, player)
	_pending.clear()
	# Boss斩败抽帧/命中停顿可令delta为0，但已发生的死亡不能推迟奖励。
	if delta <= 0.0: return
	_accumulator += delta
	while _accumulator + 0.0000001 >= SOURCE_STEP:
		_accumulator -= SOURCE_STEP
		_advance_source_frame(SOURCE_STEP)
	if not souls.is_empty() or not drops.is_empty(): queue_redraw()

func _get_recipient(entry: Dictionary) -> BattleEntity2D:
	var killer := entry.killer as BattleEntity2D
	if is_instance_valid(killer) and killer.inventory is OriginalInventory and killer.faction_id == &"player": return killer
	var nearest: BattleEntity2D
	var distance := INF
	for entity in session.get_entities():
		if not entity is BattleEntity2D or entity.faction_id != &"player" or not entity.inventory is OriginalInventory: continue
		var candidate: float = entity.global_position.distance_squared_to(entry.position)
		if candidate < distance: nearest = entity; distance = candidate
	return nearest

func _award(id: StringName, entry: Dictionary, player: BattleEntity2D) -> void:
	if awarded.has(id) or not is_instance_valid(entry.monster): return
	awarded[id] = true
	var mob_id: String = _monster_ids[entry.monster.definition_id]
	var drop_ids: Array = rules.data.monster_drops.get(mob_id, [])
	var experience := 0
	var spirit := 0
	var selected: Array[StringName] = []
	for drop_id in drop_ids:
		var row: Dictionary = rules.data.drops.get(String(drop_id), {})
		if row.is_empty(): continue
		experience += int(row.get("exp", 0))
		spirit += int(row.get("spirit", 0))
		_select_items(row, "itemId", "itemProbability", int(row.get("itemMaxNum", 0)), selected)
		_select_items(row, "equip_%d" % (player.inventory as OriginalInventory).role_condition, "equProbability", int(row.get("equMaxNum", 0)), selected)
	player.attributes.add_experience(experience)
	(player.inventory as OriginalInventory).grant_spirit(spirit)
	if spirit > 0: spawn_soul(entry.position + Vector2(0, -30) * source_unit_scale, player)
	for item_id in selected: spawn_item(item_id, entry.position, player)
	session.publish_event(&"battle.loot.rewarded", player, entry.monster, {"experience": experience, "spirit": spirit, "items": selected.duplicate()})

func _select_items(row: Dictionary, id_key: String, chance_key: String, attempts: int, selected: Array[StringName]) -> void:
	var ids := String(row.get(id_key, "-1")).split(";")
	var chances := String(row.get(chance_key, "0")).split(";")
	if ids.size() != chances.size(): return
	for _attempt in range(attempts):
		if int(row.get("type", 0)) == 0:
			var total := 0.0
			for chance in chances: total += maxf(0, float(chance))
			if total <= 0: continue
			var value := session.random.random_float(&"loot.items") * total
			for index in range(ids.size()):
				value -= maxf(0, float(chances[index]))
				if value < 0:
					if ids[index].to_int() > 0: selected.append(StringName(ids[index]))
					break
		else:
			for index in range(ids.size()):
				if session.random.roll(float(chances[index]), &"loot.items") and ids[index].to_int() > 0: selected.append(StringName(ids[index]))

func spawn_item(id: StringName, at: Vector2, player: BattleEntity2D) -> bool:
	var definition := catalog.get_definition(id)
	if definition == null: push_error("掉落物品定义缺失：" + String(id)); return false
	var instance := definition.create_instance()
	(player.inventory as OriginalInventory).roll_equipment_attributes(instance, session.random)
	var offset := (session.random.random_float(&"loot.visual") * 40 - 20) * source_unit_scale
	drops.append({"item": instance, "position": at + Vector2(offset, -20 * source_unit_scale), "velocity": Vector2(offset * 3, -200 * source_unit_scale), "owner": player.entity_id, "age": 0.0, "grounded": false, "retry": 0.0})
	queue_redraw()
	return true

func spawn_soul(at: Vector2, player: BattleEntity2D) -> void:
	souls.append({"position": at, "velocity": Vector2(0, -600) * source_unit_scale, "owner": player.entity_id, "age": 0.0, "seeking": false, "finished": false, "trail": []})
	queue_redraw()

func _advance_source_frame(delta: float) -> void:
	for index in range(drops.size()-1, -1, -1):
		var drop: Dictionary = drops[index]
		drop.age += delta
		if drop.age > drop_lifetime: drops.remove_at(index); queue_redraw(); continue
		if not drop.grounded:
			var before: Vector2 = drop.position
			drop.velocity.y += 2000.0 * delta
			var next: Vector2 = before + drop.velocity * delta
			var query := PhysicsRayQueryParameters2D.create(before, next + Vector2(0, 8 * source_unit_scale), 1)
			var hit := get_world_2d().direct_space_state.intersect_ray(query)
			if not hit.is_empty() and Vector2(hit.normal).y < -0.5:
				drop.position = Vector2(hit.position) - Vector2(0, 8 * source_unit_scale)
				drop.velocity = Vector2.ZERO
				drop.grounded = true
			else: drop.position = next
		var player := session.get_entity(drop.owner) as BattleEntity2D
		if not is_instance_valid(player) or not player.is_alive(): continue
		drop.retry = maxf(0, float(drop.retry) - delta)
		var auto_pick: bool = int(drop.item.original_data.get("isAutoPick", 0)) != 0 and bool(drop.grounded)
		var texture: Texture2D = drop.item.pickup_icon if drop.item.pickup_icon != null else drop.item.icon as Texture2D
		var touching := _pickup_geometry.touches(player.get_body_rect_global(), global_transform, drop.position, texture.get_size() if texture != null else Vector2.ZERO, source_unit_scale, pickup_radius)
		if drop.retry <= 0 and (auto_pick or touching):
			if pickup_drop(index, player): continue
			# 满值补给只做廉价Vital检查，缺值后下一源帧即可拾取；满背包保持1秒重试。
			drop.retry = 0.0 if int(drop.item.original_data.get("propType", 0)) == 1014 else 1.0
	for index in range(souls.size()-1, -1, -1):
		var soul: Dictionary = souls[index]
		for segment: Dictionary in soul.trail: segment.age += delta
		while not soul.trail.is_empty() and float(soul.trail[0].age) >= 4.0 / 30.0: soul.trail.pop_front()
		if soul.finished:
			if soul.trail.is_empty(): souls.remove_at(index); queue_redraw()
			continue
		soul.age += delta
		var player := session.get_entity(soul.owner) as BattleEntity2D
		if not is_instance_valid(player) or soul.age > 10: soul.finished = true; continue
		var before: Vector2 = soul.position
		if soul.age >= 0.3:
			if not soul.seeking: soul.velocity = Vector2(1000, 0) * source_unit_scale; soul.seeking = true
			var destination := player.global_position + Vector2(0, -60) * source_unit_scale
			var desired := (destination - before).normalized() * 1000.0 * source_unit_scale
			soul.velocity = (Vector2(soul.velocity) + (desired - Vector2(soul.velocity)).limit_length(100 * source_unit_scale)).limit_length(1000 * source_unit_scale)
			soul.position += soul.velocity * delta
			soul.trail.append({"from": before, "to": soul.position, "age": 0.0})
			# 检查扫过的路径，低帧率/高速时不能越过玩家后绕圈。
			var closest := Geometry2D.get_closest_point_to_segment(destination, before, soul.position)
			if closest.distance_to(destination) < 40 * source_unit_scale: soul.finished = true
		else:
			soul.velocity.y += 2000.0 * delta
			soul.position += soul.velocity * delta

func pickup_drop(index: int, player: BattleEntity2D) -> bool:
	if index < 0 or index >= drops.size() or not is_instance_valid(player) or not player.is_alive(): return false
	var drop: Dictionary = drops[index]
	if drop.owner != player.entity_id: return false
	var item := drop.item as Item
	var bag := player.inventory as OriginalInventory
	if bag == null: return false
	var is_supply := int(item.original_data.get("propType", 0)) == 1014
	var restored_vital: StringName = &""
	var restored_amount: int = 0
	if is_supply:
		# 原拾取药品直接按最大生命/魔法比例回复，不进入背包。
		var type := String(item.original_data.get("attributeT1", ""))
		var vital := player.attributes.get_vital(&"health" if type == "hpMax" else &"mana")
		if type not in ["hpMax", "mpMax"] or vital == null: return false
		if vital.current_value >= vital.get_max_value(): return false
		var previous := vital.current_value
		vital.set_current_value(vital.current_value + floorf(vital.get_max_value() * float(item.original_data.get("attributeV1", 0))))
		restored_vital = &"health" if type == "hpMax" else &"mana"
		restored_amount = roundi(vital.current_value - previous)
	else:
		if not bag.try_add_item(item, false): return false
	drops.remove_at(index)
	var texture: Texture2D = item.pickup_icon if item.pickup_icon != null else item.icon as Texture2D
	var transform := get_global_transform_with_canvas()
	session.publish_event(&"battle.loot.picked_up", player, null, {"item_id": item.item_id, "item_unique_id": item.runtime.unique_id, "is_supply":is_supply, "restored_vital":restored_vital, "restored_amount":restored_amount, "pickup_texture":texture, "screen_position":transform * to_local(drop.position), "screen_size":texture.get_size() * source_unit_scale * transform.get_scale().abs() if texture != null else Vector2.ZERO})
	queue_redraw()
	return true

func clear_loot() -> void:
	drops.clear(); souls.clear(); awarded.clear(); _pending.clear(); _accumulator = 0.0
	if session != null: session.publish_event(&"battle.loot.cleared")
	queue_redraw()

func get_quality_glow_index(item: Item) -> int:
	if item == null or int(item.original_data.get("propType", 0)) == 1014: return -1
	var quality := int(item.original_data.get("quality", 0))
	return quality if quality >= 0 and quality < quality_glows.size() else -1

func _draw() -> void:
	for drop: Dictionary in drops:
		var item := drop.item as Item
		var quality := get_quality_glow_index(item)
		if quality >= 0:
			var glow := quality_glows[quality]
			if glow != null:
				var pivot := quality_glow_pivots[quality] if quality < quality_glow_pivots.size() else -glow.get_size() / 2.0
				draw_texture_rect(glow, Rect2(to_local(drop.position) + pivot * source_unit_scale, glow.get_size() * source_unit_scale), false)
		var texture: Texture2D = item.pickup_icon if item.pickup_icon != null else item.icon as Texture2D
		if texture != null:
			var dimensions := texture.get_size() * source_unit_scale
			draw_texture_rect(texture, Rect2(to_local(drop.position) - dimensions / 2, dimensions), false)
	for soul: Dictionary in souls:
		for segment: Dictionary in soul.trail:
			var alpha := clampf(1.0 - float(segment.age) * 30 / 4, 0, 1)
			var start := to_local(segment.from)
			var end := to_local(segment.to)
			for width in [12.0, 7.0]: draw_line(start, end, Color(0.86, 0.26, 0.93, alpha * 0.15), width * source_unit_scale, true)
			draw_line(start, end, Color(1, 1, 1, alpha), maxf(1, (2.0 - float(segment.age) * 30 * 0.25) * source_unit_scale), true)
		if not soul.finished and spirit_texture != null:
			var dimensions := spirit_texture.get_size() * source_unit_scale
			draw_texture_rect(spirit_texture, Rect2(to_local(soul.position) - dimensions / 2, dimensions), false)
#endregion
