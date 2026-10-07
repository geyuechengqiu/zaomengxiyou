extends RefCounted
class_name BattleFactions
#region 阵营关系
enum Relation { HOSTILE = -1, NEUTRAL = 0, FRIENDLY = 1 }
var _relations: Dictionary = {}
#endregion
#region 公共接口
func set_relation(first: StringName, second: StringName, relation: Relation, mutual: bool = true) -> void:
	_relations[_key(first, second)] = relation
	if mutual:
		_relations[_key(second, first)] = relation

func get_relation(first: StringName, second: StringName) -> Relation:
	if _relations.has(_key(first, second)):
		return _relations[_key(first, second)]
	if first == &"neutral" or second == &"neutral":
		return Relation.NEUTRAL
	return Relation.FRIENDLY if first == second else Relation.NEUTRAL

func is_hostile(first: StringName, second: StringName) -> bool:
	return get_relation(first, second) == Relation.HOSTILE
#endregion
#region 内部实现
func _key(first: StringName, second: StringName) -> Array:
	return [first, second]
#endregion
