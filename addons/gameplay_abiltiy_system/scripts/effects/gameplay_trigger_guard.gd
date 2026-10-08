extends RefCounted
class_name GameplayTriggerGuard
#region 同步效果链的深度预算
const MAX_DEPTH: int = 16
static var depth: int = 0
static var blocked_count: int = 0

static func enter() -> bool:
	if depth >= MAX_DEPTH:
		blocked_count += 1
		return false
	depth += 1
	return true

static func leave() -> void:
	depth = maxi(0, depth - 1)
#endregion
