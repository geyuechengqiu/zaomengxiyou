extends RefCounted
class_name BattleAttackInstance
#region 一次施放的攻击状态
var attack_id: StringName
var ability_id: StringName
var attacker_id: StringName
var faction_id: StringName
var attacker: WeakRef
var elapsed: float = 0.0
var active: bool = true
## hit_index -> 窗口上下文；每个窗口均独立去重，第四段仍允许两次命中。
var windows: Dictionary = {}
var hit_targets: Dictionary = {}

func initialize(owner_entity: BattleEntity2D, skill_id: StringName, serial: int) -> void:
	attacker = weakref(owner_entity)
	attacker_id = owner_entity.entity_id
	faction_id = owner_entity.faction_id
	ability_id = skill_id
	attack_id = StringName("%s/attack/%d" % [attacker_id, serial])

func open_window(context: Dictionary, duration: float) -> bool:
	var index := int(context.get("hit_index", 1))
	if not active or index < 1 or windows.has(index):
		return false
	var data := context.duplicate(true)
	data["window_end"] = float(context.skill_time) + maxf(0.0, duration)
	windows[index] = data
	return true

func register_hit(index: int, target_id: StringName) -> bool:
	var key := "%d/%s" % [index, target_id]
	if not active or hit_targets.has(key):
		return false
	hit_targets[key] = true
	return true

func close() -> void:
	active = false
	windows.clear()
#endregion
