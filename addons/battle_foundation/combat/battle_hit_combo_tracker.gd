extends Node
class_name BattleHitComboTracker
#region 按角色归属计数；由会话的战斗时钟推进，不由界面推进
signal combo_changed(owner_id: StringName, count: int, maximum: int)
@export_range(0.01, 10.0) var timeout_seconds: float = 1.5
var _roles: Dictionary = {}
var _owners: Dictionary[StringName, StringName] = {}
var _settled_floor: int = 0
var _pending_settlements: Dictionary[int, bool] = {}
var maximum_combo: int = 0
var session: BattleSession:
	get: return get_parent() as BattleSession

func _enter_tree() -> void:
	_settled_floor = session._damage_serial
	CoreSystem.event_bus.event_pushed.connect(_on_event)

func _exit_tree() -> void:
	CoreSystem.event_bus.event_pushed.disconnect(_on_event)

## 同一角色再次绑定 HUD 不重置连击。角色实例互相独立。
func register_role(owner_id: StringName) -> void:
	if not _roles.has(owner_id):
		_roles[owner_id] = {"count": 0, "maximum": 0, "last_hit": 0.0}

## 召唤物/宠物的命中归属角色；没有归属的怪物不会计入玩家连击。
func set_hit_owner(source_id: StringName, owner_id: StringName) -> bool:
	if not _roles.has(owner_id): return false
	_owners[source_id] = owner_id
	return true

func get_count(owner_id: StringName) -> int:
	return int(_roles.get(owner_id, {}).get("count", 0))

func get_maximum(owner_id: StringName) -> int:
	return int(_roles.get(owner_id, {}).get("maximum", 0))

func advance_combat() -> void:
	for owner_id: StringName in _roles:
		_expire(owner_id)

func _expire(owner_id: StringName) -> void:
	var row: Dictionary = _roles[owner_id]
	if int(row.count) > 0 and session.clock.elapsed - float(row.last_hit) >= timeout_seconds - 0.0000001:
		reset_chain(owner_id)

func reset_chain(owner_id: StringName) -> void:
	if not _roles.has(owner_id): return
	var row: Dictionary = _roles[owner_id]
	if int(row.count) == 0: return
	row.count = 0
	_notify(owner_id)

func clear_battle() -> void:
	for owner_id: StringName in _roles:
		reset_chain(owner_id)
	_roles.clear()
	_owners.clear()
	_settled_floor = session._damage_serial
	_pending_settlements.clear()
	maximum_combo = 0

func remove_entity(entity_id: StringName) -> void:
	reset_chain(entity_id)
	_roles.erase(entity_id)
	_owners.erase(entity_id)
	for source_id: StringName in _owners.keys():
		if _owners[source_id] == entity_id: _owners.erase(source_id)

func _notify(owner_id: StringName) -> void:
	combo_changed.emit(owner_id, get_count(owner_id), get_maximum(owner_id))
	session.publish_event(&"battle.hit_combo.changed", session.get_entity(owner_id), null,
		{"owner_id": owner_id, "count": get_count(owner_id), "maximum": get_maximum(owner_id), "level_maximum": maximum_combo})
#endregion
#region 单一 Core 结算入口；不同时消费 attack.hit 和 hit.effective
func _on_event(event_id: String, payload: Array) -> void:
	if payload.size() != 1 or not payload[0] is Dictionary: return
	var data: Dictionary = payload[0]
	if data.get("battle_id") != session.battle_id: return
	if event_id == "battle.entity_spawned" and data.get("category") == "characters":
		register_role(StringName(data.target_entity_id))
	elif event_id == "battle.entity.killed":
		reset_chain(StringName(data.target_entity_id))
	elif event_id == "battle.entity_despawned":
		remove_entity(StringName(data.target_entity_id))
	elif event_id == "battle.damage.settled":
		# hit.effective回调可能先结算较新的次生伤害；只保留尚未闭合的序号间隙。
		var serial := String(data.get("damage_id", "")).get_slice("/damage/", 1).to_int()
		if serial <= _settled_floor or _pending_settlements.has(serial): return
		_pending_settlements[serial] = true
		while _pending_settlements.has(_settled_floor + 1):
			_settled_floor += 1
			_pending_settlements.erase(_settled_floor)
		if data.get("damage_kind", &"attack") != &"attack": return
		# 原版 showHitCombox 检查 damageValue != 0；纯真实附伤、闪避和免疫不计数。
		if float(data.get("normal_damage", 0.0)) == 0.0 or data.get("is_dodged", false) or data.get("is_immune", false): return
		var source_id := StringName(data.source_entity_id)
		var owner_id: StringName = _owners.get(source_id, source_id)
		if not _roles.has(owner_id): return
		var owner: Node = session.get_entity(owner_id)
		if not is_instance_valid(owner) or not owner.is_alive(): return
		_expire(owner_id)
		var row: Dictionary = _roles[owner_id]
		row.count = int(row.count) + 1
		row.maximum = maxi(int(row.maximum), int(row.count))
		maximum_combo = maxi(maximum_combo, int(row.count))
		row.last_hit = session.clock.elapsed
		_notify(owner_id)
#endregion
