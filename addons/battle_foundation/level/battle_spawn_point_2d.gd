extends Marker2D
class_name BattleSpawnPoint2D
#region 编辑器预置出生点
@export var spawn_point_id: StringName
@export var random_position: bool = false
@export var random_rect: Rect2 = Rect2(0, 0, 32, 32)

func sample_position(random: BattleRandom) -> Vector2:
	if not random_position: return global_position
	var offset := random_rect.position + Vector2(random.random_float(&"level_spawning"), random.random_float(&"level_spawning")) * random_rect.size
	return to_global(offset)
#endregion
