extends Node2D
class_name BattleCombatFeedback2D
#region 生命条与单次伤害反馈
@onready var _actor: BattleEntity2D = get_parent() as BattleEntity2D
@onready var _health: ProgressBar = $HealthBar
@onready var _label: Label = $HealthLabel
@onready var _damage: Label = $DamageLabel
var remaining: float = 0.0
var last_damage: float = 0.0
var hit_count: int = 0

func _ready() -> void:
	_actor.attributes.snapshot_changed.connect(_refresh_health)
	_refresh_health(_actor.attributes.get_snapshot())
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	_damage.visible = false

func _exit_tree() -> void:
	if CoreSystem.event_bus.event_pushed.is_connected(_on_event):
		CoreSystem.event_bus.event_pushed.disconnect(_on_event)

func _refresh_health(snapshot: Dictionary) -> void:
	_health.max_value = maxf(1.0, snapshot.hpMax)
	_health.value = snapshot.hp
	_label.text = "%.0f / %.0f" % [snapshot.hp, snapshot.hpMax] if snapshot.hp > 0.0 else "已击杀"

func _on_event(id: String, payload: Array) -> void:
	if id != "battle.attack.hit" or payload.size() != 1:
		return
	var data: Dictionary = payload[0]
	if data.get("battle_id") != _actor.session.battle_id or data.get("target_entity_id") != _actor.entity_id:
		return
	last_damage = data.damage
	hit_count += 1
	remaining = 0.65
	_damage.text = "−%.0f" % last_damage if last_damage > 0.0 else "格挡"
	_damage.position.y = -260.0
	_damage.modulate.a = 1.0
	_damage.visible = true

func advance_feedback(delta: float) -> void:
	if remaining <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	_damage.position.y -= delta * 35.0
	_damage.modulate.a = minf(1.0, remaining / 0.2)
	_damage.visible = remaining > 0.0
#endregion
