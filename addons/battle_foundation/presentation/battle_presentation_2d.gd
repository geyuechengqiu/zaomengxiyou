extends Node2D
class_name BattlePresentation2D
#region 战斗场景共享的表现入口
@export var feedback_scene: PackedScene
@export var number_scene: PackedScene
@onready var entity_views: Node2D = $EntityViews
@onready var number_rows: BattleDamageNumberLayer2D = $DamageNumbers/Rows
var _session: BattleSession
var _views: Dictionary = {}

func _ready() -> void:
	_session = get_parent() as BattleSession
	assert(_session != null, "BattlePresentation 必须放在 BattleSession 下")
	CoreSystem.event_bus.event_pushed.connect(_on_event)

func register_actor(actor: BattleEntity2D) -> void:
	if actor.session != _session or _views.has(actor.entity_id):
		return
	var view: BattleCombatFeedback2D
	for child in entity_views.get_children():
		if child is BattleCombatFeedback2D and not child.actor_path.is_empty() and child.get_node_or_null(child.actor_path) == actor:
			view = child
			break
	if view == null:
		# 动态出生目标的反馈是表现实例；公共管理器与数字池由场景预置。
		view = feedback_scene.instantiate() as BattleCombatFeedback2D
		entity_views.add_child(view)
	_views[actor.entity_id] = view
	if actor.ai_controller is BattleBossController2D:
		view.health_bar_enabled = false
		view.show_protection_bar = false
	elif actor.protection.profile != null and actor.protection.profile.has_meta(&"original_protect_skill_id") and not actor.protection.profile.use_as_armor:
		# 原showProtect用于BossBleed；普通怪物头顶不额外画调试保护条。
		view.show_protection_bar = false
	view.bind_actor(actor, self)
	if _session.audio != null: _session.audio.register_actor(actor)

func get_feedback(actor: BattleEntity2D) -> BattleCombatFeedback2D:
	return _views.get(actor.entity_id) as BattleCombatFeedback2D

func remove_actor(id: StringName) -> void:
	if _session.audio != null: _session.audio.remove_actor(id)
	var view := _views.get(id) as BattleCombatFeedback2D
	_views.erase(id)
	if is_instance_valid(view):
		view.unbind_actor()
		if view.actor_path.is_empty():
			view.queue_free()
	# 已发出的数字属于本场战斗，目标离场后仍播放至自然结束。

func clear_presentations() -> void:
	for id in _views.keys():
		remove_actor(id)
	number_rows.clear_numbers()
	if _session.audio != null: _session.audio.clear_audio()
	var boss := get_node_or_null(^"BossFeedback") as BattleBossFeedback2D
	if boss != null: boss.clear_feedback()
	var stage := get_node_or_null(^"StageFeedback") as BattleStageFeedback
	if stage != null: stage.clear_feedback()

func filter_combat_delta(delta: float) -> float:
	var stage := get_node_or_null(^"StageFeedback") as BattleStageFeedback
	return stage.filter_combat_delta(delta) if stage != null else delta

func advance_ui(delta: float) -> void:
	var stage := get_node_or_null(^"StageFeedback") as BattleStageFeedback
	if stage != null: stage.advance_ui(delta)

func advance_presentation(delta: float) -> void:
	if _session.audio != null: _session.audio.advance_audio()
	for view: BattleCombatFeedback2D in _views.values():
		view.advance_feedback(delta)
	# 每场战斗每个 tick 仅推进一次，数量与目标数无关。
	number_rows.advance_numbers(delta)
	var boss := get_node_or_null(^"BossFeedback") as BattleBossFeedback2D
	if boss != null:
		boss.advance_feedback(delta)
		boss.synchronize_pause(_session.is_simulation_blocked())

func _on_event(id: String, payload: Array) -> void:
	if id not in ["battle.attack.hit", "battle.damage.settled", "battle.loot.picked_up"] or payload.size() != 1 or not payload[0] is Dictionary:
		return
	var data: Dictionary = payload[0]
	if id == "battle.damage.settled" and bool(data.get("defer_attack_feedback", false)):
		return
	if data.get("battle_id") != _session.battle_id:
		return
	if id == "battle.loot.picked_up":
		var recipient := _views.get(data.get("source_entity_id")) as BattleCombatFeedback2D
		if is_instance_valid(recipient) and data.get("is_supply", false):
			recipient.show_supply_recovery(data.get("restored_vital", &""), int(data.get("restored_amount", 0)))
		return
	var view := _views.get(data.get("target_entity_id")) as BattleCombatFeedback2D
	if is_instance_valid(view):
		view.show_hit(data)

func _exit_tree() -> void:
	if CoreSystem.event_bus.event_pushed.is_connected(_on_event):
		CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	_views.clear()
#endregion
