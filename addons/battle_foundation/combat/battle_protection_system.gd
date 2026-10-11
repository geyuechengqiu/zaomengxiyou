extends Node
class_name BattleProtectionSystem
## 目标拥有自己的条和技能次数；次数跨释放延续，不属于 BattleAttackInstance。

#region 独立运行数据与已导入原版定义
var profile: BattleProtectionProfile
var score: int = 0
var passive_score: int = 0
var previous_score: int = 0
var maximum: int = 0
var show_protect: bool = false
var hit_counts: Dictionary = {}
var active: bool = false
var active_remaining: float = 0.0
var inactive_seconds: float = 0.0
var trigger_count: int = 0
var last_increment: int = 0
var last_error: String = ""
var _owner: WeakRef
var _skills: Dictionary = {}
var _aliases: Dictionary = {}
var _dimmed: bool = false
var _original_alpha: float = 1.0
## 原保护表约2MB：只解析一次，技能/别名只读共享；累计值仍由各组件保存。
static var _source_cache: Dictionary = {}
static var source_parse_count: int = 0

static func load_original_source(path: String) -> Dictionary:
	if _source_cache.has(path): return _source_cache[path]
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("version") != 1: return {}
	_source_cache[path] = parsed
	source_parse_count += 1
	return parsed
#endregion
#region 初始化、Boss 满值与技能配置查询
func configure(actor: BattleEntity2D, definition: BattleProtectionProfile) -> bool:
	_owner = weakref(actor)
	profile = definition
	if profile == null or not profile.enabled:
		return true
	if not profile.is_valid():
		last_error = "保护条配置无效"
		return false
	var parsed := load_original_source(profile.original_data_path)
	if parsed.is_empty():
		last_error = "保护条原版数据缺失或版本错误：" + profile.original_data_path
		return false
	_skills = parsed.get("skills", {})
	_aliases = parsed.get("ability_ids", {})
	var boss: Dictionary = parsed.get("bosses", {}).get(profile.original_boss_key, {})
	show_protect = profile.show_protect and (not profile.inherit_original_display or bool(boss.get("showProtect", true)))
	maximum = profile.maximum_override if profile.maximum_override > 0 else int(boss.get("protectPoint", 0))
	if maximum <= 0:
		last_error = "Boss 满值未配置：" + profile.original_boss_key
		return false
	if profile.multiplayer_enemy:
		maximum = int(maximum * (1.0 + profile.multiplayer_bonus))
	return true

func get_skill_parameters(context: Dictionary) -> Dictionary:
	var skill_id := str(context.get("protection_skill_id", context.get("original_skill_id", "")))
	if skill_id.is_empty():
		var ability := str(context.get("sub_skill_id", context.get("ability_id", "")))
		if ability.is_empty():
			ability = str(context.get("ability_id", ""))
		skill_id = str(_aliases.get(ability, ability))
	var data: Dictionary = _skills.get(skill_id, {}).duplicate(true)
	data["id"] = skill_id
	# 显式原版字段覆盖，不能把旧的固定 protection_value 当作 Boss 满值。
	data.merge(context.get("protection_parameters", {}), true)
	return data
#endregion
#region 普通 PvE / PvP 的累计与触发
func register_hit(context: Dictionary, actual_damage: float, max_health: float, multiplier: float = 1.0) -> Dictionary:
	if profile == null or not profile.enabled or (active and not profile.counts_while_active):
		return {"increment": 0, "triggered": false}
	if not is_finite(multiplier) or multiplier < 0.0:
		return {"increment": 0, "triggered": false}
	_reset_if_inactive()
	inactive_seconds = 0.0
	var data := get_skill_parameters(context)
	var key := _count_key(data, context)
	var previous_count := int(hit_counts.get(key, 0))
	var count := previous_count + 1
	var n := count if int(data.get("isProtectPointAdd", 1)) != 0 else 1
	var competitive: bool = bool(context.get("is_pvp", false)) or bool(context.get("is_qc", false)) or bool(context.get("is_pk", false)) or bool(context.get("is_arena", false)) or bool(context.get("is_tongtian", false)) or bool(context.get("countdown_mode", false))
	var pvp_fields: bool = bool(context.get("pvp_protection_fields", competitive))
	var prefix := "pvpProtectPoint" if pvp_fields else "protectPoint"
	var base := float(data.get(prefix, context.get("protection_value", 0.0)))
	var increase := float(data.get(prefix + "B", 0.0))
	var cap: Variant = data.get(prefix + "Max")
	# 原版 || 999999999：未设置（null）或 0 都表示未设限，而非零满值。
	var limit := float(cap) if cap != null and float(cap) > 0.0 else 999999999.0
	last_increment = maxi(0, int(int(minf(base + increase * (n - 1), limit)) * multiplier))
	# 原版增量为零时撤回本次技能计数，避免空增量推动递增序列。
	if last_increment > 0:
		hit_counts[key] = count
	if bool(context.get("is_pvp", false)) or bool(context.get("is_qc", false)):
		last_increment += int(maxf(0.0, actual_damage) / maxf(1.0, max_health) * 50000.0)
	score += last_increment
	var triggered := score >= maximum
	var result := {"increment": last_increment, "count_key": key, "count": n, "score_before_trigger": score, "maximum": maximum, "triggered": triggered}
	if triggered:
		_trigger()
	_publish(&"battle.protection.changed", result)
	return result

func _count_key(data: Dictionary, context: Dictionary) -> String:
	if not str(context.get("protection_count_key", "")).is_empty():
		return str(context.protection_count_key)
	var id := str(data.get("id", ""))
	if id in ["1103122", "1103123", "1103124", "1103125"]:
		return "1103121"
	if id == "1101622":
		return "1101620"
	var merge_id: Variant = data.get("addXpBySkillId")
	return str(int(merge_id)) if merge_id != null and int(merge_id) > 0 else id

func _trigger() -> void:
	previous_score = score
	score = 0
	passive_score = 0
	hit_counts.clear()
	trigger_count += 1
	var actor := _owner.get_ref() as BattleEntity2D if _owner != null else null
	var started := actor != null and actor.reactions.start_protection()
	active = started
	active_remaining = profile.protect_seconds if started else 0.0
	# 原版护甲模式：动作失败恢复触发前数值，但技能次数仍然清空。
	if profile.use_as_armor:
		score = maximum if started else previous_score
	_publish(&"battle.protection.triggered", {"previous_score": previous_score, "maximum": maximum, "action_started": started, "armor_mode": profile.use_as_armor})
#endregion
#region 统一战斗时钟、清理与事件
func advance(delta: float) -> void:
	if delta <= 0.0 or profile == null or not profile.enabled:
		return
	inactive_seconds += delta
	if active:
		active_remaining = maxf(0.0, active_remaining - delta)
		if active_remaining <= 0.0:
			active = false
			if profile.use_as_armor:
				score = 0
			_publish(&"battle.protection.ended")
	_reset_if_inactive()

func _reset_if_inactive() -> void:
	if not profile.use_as_armor and profile.inactivity_reset_seconds > 0.0 and inactive_seconds + 0.000000001 >= profile.inactivity_reset_seconds and (score != 0 or not hit_counts.is_empty()):
		score = 0
		passive_score = 0
		hit_counts.clear()
		_publish(&"battle.protection.reset", {"reason": &"inactivity"})

func clear() -> void:
	_restore_alpha()
	score = 0
	passive_score = 0
	previous_score = 0
	hit_counts.clear()
	active = false
	active_remaining = 0.0
	inactive_seconds = 0.0

func refresh_visual() -> void:
	var actor := _owner.get_ref() as BattleEntity2D if _owner != null else null
	if actor == null or actor.animation == null: return
	var dim := profile != null and profile.invulnerable_alpha and TagManager.has_tag(actor, &"state.invulnerable") and actor.is_alive()
	if dim and not _dimmed:
		_original_alpha = actor.animation.modulate.a
		actor.animation.modulate.a = _original_alpha * 0.5
		_dimmed = true
	elif not dim: _restore_alpha()

func _restore_alpha() -> void:
	var actor := _owner.get_ref() as BattleEntity2D if _owner != null else null
	if _dimmed and actor != null and is_instance_valid(actor.animation): actor.animation.modulate.a = _original_alpha
	_dimmed = false

func _publish(id: StringName, payload: Dictionary = {}) -> void:
	var actor := _owner.get_ref() as BattleEntity2D if _owner != null else null
	if actor != null and actor.session != null:
		actor.publish_battle_event(id, payload)
#endregion
