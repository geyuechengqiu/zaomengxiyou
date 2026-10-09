extends Node
class_name BattleWushuangController
#region 配置、GAS Vital 与独立角色运行状态
@export var status_id: StringName = &"normal_wushuang_visual"
@export var armor_id: StringName = &"sunwukong_wushuang_armor"
var actor: BattleEntity2D
var rage: GameplayVital
var using_wushuang: bool = false
var _duration: float = 15.0
var _lowest_hp_percent: int = 100
static var _rules: Dictionary = {}

static func get_original_rules() -> Dictionary:
	if _rules.is_empty():
		_rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/effects/wushuang/combat_rules.json"))
	return _rules

func bind(owner_actor: BattleEntity2D) -> void:
	actor = owner_actor
	rage = actor.attributes.get_vital(&"rage")
	actor.statuses.status_removed.connect(_on_status_removed)
	if rage != null: rage.value_changed.connect(_on_value_changed)

func can_activate() -> bool:
	return rage != null and actor.is_alive() and not actor.is_spawning() and not actor.session.is_simulation_blocked() and not using_wushuang and rage.current_value >= rage.get_max_value() and not TagManager.has_tag(actor, &"state.stunned")

func add_rage(amount: float) -> float:
	if rage == null or using_wushuang or not actor.is_alive() or not is_finite(amount): return 0.0
	var previous := rage.current_value
	rage.modify_value(amount * (1.0 + actor.damage_rules.get_number(&"xpRatio")))
	return rage.current_value - previous

func _on_value_changed(value: float, maximum: float, percent: float, _regen: bool) -> void:
	actor.publish_battle_event(&"battle.wushuang.changed", {"rage": roundi(value), "rage_max": roundi(maximum), "percent": percent, "active": using_wushuang})
#endregion
#region 无双起手、硬直释放、统一战斗时钟与清理
func activate(status: GameplayStatusData, armor: GameplayStatusData) -> void:
	if not can_activate(): return
	using_wushuang = true
	_duration = maxf(0.001, status.duration)
	# 原版onStiffComplete只解除硬直；不清除眩晕，也不改变技能/跳跃许可。
	if actor.action_state.current == BattleActionState2D.State.HURT:
		actor.motion.clear_impulse()
		actor.action_state.enter(BattleActionState2D.State.IDLE if actor.motion.grounded else BattleActionState2D.State.JUMP)
		actor.refresh_action_animation(true)
	actor.statuses.apply_status(status, actor)
	if armor != null: actor.statuses.apply_status(armor, actor)
	actor.publish_battle_event(&"battle.wushuang.started", {"duration": _duration})

func advance_simulation(delta: float) -> void:
	if not using_wushuang or rage == null or delta <= 0: return
	rage.modify_value(-rage.get_max_value() / _duration * delta)
	if rage.current_value <= 0.000001:
		actor.statuses.remove_status(status_id)

func _on_status_removed(id: StringName) -> void:
	if id != status_id or not using_wushuang: return
	using_wushuang = false
	if rage != null: rage.set_current_value(0.0)
	actor.statuses.remove_status(armor_id)
	actor.publish_battle_event(&"battle.wushuang.ended")

func clear() -> void:
	if actor == null: return
	actor.statuses.remove_status(status_id)
	actor.statuses.remove_status(armor_id)
	using_wushuang = false
	if rage != null: rage.set_current_value(0.0)
#endregion
#region 原版命中获取：整次释放预算、目标最低生命百分比记录
static func register_attack_hit(attacker: BattleEntity2D, target: BattleEntity2D, cast: BattleAttackInstance, info: DamageInfo, context: Dictionary) -> void:
	# 由统一真实攻击入口调用；DOT、反伤和重复重叠不会额外进入此路径。
	if cast == null or info.is_dodged: return
	var id := String(context.get("ability_id", cast.ability_id))
	var config: Dictionary = get_original_rules().skills.get(id, {})
	var amount := float(config.get("addXP", 0))
	var maximum := float(config.get("addXPMax", 0))
	if maximum <= 0: maximum = amount * int(config.get("atkMax", 1))
	if amount <= 0 or cast.rage_awarded >= maximum: return
	amount = minf(amount, maximum - cast.rage_awarded)
	cast.rage_awarded += amount
	if attacker.wushuang != null: attacker.wushuang.add_rage(amount)
	if target.wushuang != null: target.wushuang._register_received_hit()

func _register_received_hit() -> void:
	var maximum := actor.attributes.get_value(&"hpMax")
	if maximum <= 0: return
	var hp_percent := clampi(int(actor.attributes.get_vital_value(&"health") / maximum * 100), 0, 100)
	if hp_percent >= _lowest_hp_percent: return
	var lost_percent := _lowest_hp_percent - hp_percent
	_lowest_hp_percent = hp_percent
	# calXP内部updateXP一次，checkHurtManData对返回值再updateXP一次；保留原源码两次调用。
	var config := get_original_rules()
	add_rage(lost_percent * float(config.hpToXP) * int(config.victimAwardCalls))
#endregion
