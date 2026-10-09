extends Resource
class_name BattleBossProfile
#region 专属行为配置；运行数据由BossController保存
@export var display_name: String
@export var skills: Array[BattleBossSkillRule] = []
## 按血量阈值从高到低配置；原版没有阶段的Boss留空。
@export var phases: Array[BattleBossPhase] = []
@export var health_bar_count: int = 3
@export var maximum_summons: int = 8
## 可接入关卡已声明的额外条件：Boss死亡且召唤物全部清理后置true。
@export var completion_condition: StringName
@export var intro_seconds: float = 0.0

func is_valid() -> bool:
	if skills.is_empty() or health_bar_count < 1 or maximum_summons < 0 or not is_finite(intro_seconds) or intro_seconds < 0: return false
	var seen := {}
	for rule in skills:
		if rule == null or not rule.is_valid() or seen.has(rule.ability_id): return false
		seen[rule.ability_id] = true
	seen.clear()
	var previous := 1.0
	for phase in phases:
		if phase == null or not phase.is_valid() or seen.has(phase.phase_id) or phase.health_ratio >= previous: return false
		seen[phase.phase_id] = true
		previous = phase.health_ratio
	return true
#endregion
