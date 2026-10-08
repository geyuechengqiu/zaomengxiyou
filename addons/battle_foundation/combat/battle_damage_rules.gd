extends RefCounted
class_name BattleDamageRules
#region 每实体独立规则与普通护盾
## 属性评分仍由 GAS Attribute 提供；这些是原版 Buff/角色回调入口。
var sources: Dictionary = {}
var shields: Array[Dictionary] = []
var hooks: Dictionary = {}
var skill_levels: Dictionary = {}

func set_source(id: StringName, values: Dictionary) -> void:
	sources[id] = values.duplicate(true)

func remove_source(id: StringName) -> void:
	sources.erase(id)
	shields = shields.filter(func(row: Dictionary) -> bool: return row.source != id)

func get_number(key: StringName, fallback: float = 0.0) -> float:
	var result := 0.0
	var found := false
	for values: Dictionary in sources.values():
		if values.has(key):
			result += float(values[key])
			found = true
	return result if found else fallback

func has_flag(key: StringName) -> bool:
	for values: Dictionary in sources.values():
		if bool(values.get(key, false)):
			return true
	return false

## 同来源刷新替换；按添加顺序吸收普通分量，真实分量不进入这里。
func grant_shield(source: StringName, amount: float) -> void:
	shields = shields.filter(func(row: Dictionary) -> bool: return row.source != source)
	if amount > 0.0 and is_finite(amount):
		shields.append({"source": source, "remaining": amount})

func absorb_normal(amount: float) -> float:
	var pending := maxf(0.0, amount)
	for row in shields:
		var taken := minf(pending, row.remaining)
		row.remaining -= taken
		pending -= taken
	shields = shields.filter(func(row: Dictionary) -> bool: return row.remaining > 0.0)
	return amount - pending

func get_shield_total() -> float:
	var result := 0.0
	for row in shields:
		result += float(row.remaining)
	return result

## callback(info, target, context) 可修改分量；按注册顺序调用。
func run_hook(stage: StringName, info: DamageInfo, target: Node, context: Dictionary) -> void:
	for callback: Callable in hooks.get(stage, []).duplicate():
		if callback.is_valid():
			callback.call(info, target, context)

func clear() -> void:
	sources.clear()
	shields.clear()
	hooks.clear()
	skill_levels.clear()
#endregion
