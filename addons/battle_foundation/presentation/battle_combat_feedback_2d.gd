extends Node2D
class_name BattleCombatFeedback2D
#region 生命条与单次伤害反馈
## 预置反馈视图绑定的角色路径；动态出生目标由公共管理器绑定。
@export var actor_path: NodePath
var number_scene: PackedScene:
	get: return _presentation.number_scene
var number_rows: BattleDamageNumberLayer2D:
	get: return _presentation.number_rows
var _presentation: BattlePresentation2D
var _actor_ref: WeakRef
var _actor: BattleEntity2D:
	get: return _actor_ref.get_ref() as BattleEntity2D if _actor_ref != null else null
## 原版素材坐标到战斗坐标的比例；独立于木桩 PNG 的显示缩放。
@export var hit_effect_unit_scale: float = 2.0
## DamageControl 默认 bleedOffset，在场景坐标转屏幕后追加；只镜像 X。
@export var bleed_offset := Vector2(0, -60)
@export var original_numbers_enabled: bool = true
@export var health_bar_enabled: bool = true
@export var always_show_health_bar: bool = false
@export var show_player_health_bar: bool = false
@export var show_health_values: bool = false
@export var show_protection_bar: bool = true
@onready var _health: BattleMonsterHealthBar2D = $HealthBar
@onready var _label: Label = $HealthLabel
@onready var _damage: Label = $DamageLabel
@onready var _protection_bar: ProgressBar = $ProtectionBar
@onready var _protection_label: Label = $ProtectionLabel
@onready var hit_effect: BattleHitEffect2D = $HitEffect
@onready var appearance: BattleMonsterAppearance2D = $MonsterAppearance
var remaining: float = 0.0
var last_damage: float = 0.0
var hit_count: int = 0
var _setup_complete: bool = false

func _ready() -> void:
	visible = false

func bind_actor(actor: BattleEntity2D, presentation: BattlePresentation2D) -> void:
	unbind_actor()
	_actor_ref = weakref(actor)
	_presentation = presentation
	visible = true
	global_transform = actor.global_transform
	var snapshot := _actor.attributes.get_snapshot()
	_health.configure(health_bar_enabled and (_actor.faction_id != &"player" or show_player_health_bar), always_show_health_bar, _health.is_team or _actor.faction_id == &"player", snapshot.hp, snapshot.hpMax)
	_label.visible = show_health_values and _health.visible
	_actor.attributes.snapshot_changed.connect(_refresh_health)
	_refresh_health(snapshot)
	_damage.visible = false
	# 父场景_ready中的初始属性、补满生命不算战斗受伤。
	(_actor.attributes.get_vital(&"health") as HealthVital).damage_received.connect(_on_damage_received)
	call_deferred(&"_finish_setup")

func _finish_setup() -> void:
	_setup_complete = true

func _on_damage_received(_info: DamageInfo) -> void:
	# 若出生同帧就受到真实伤害，仍须及时显现。
	_setup_complete = true

func unbind_actor() -> void:
	if is_instance_valid(appearance): appearance.clear_effect()
	var actor := _actor
	if is_instance_valid(actor) and is_instance_valid(actor.attributes):
		if actor.attributes.snapshot_changed.is_connected(_refresh_health):
			actor.attributes.snapshot_changed.disconnect(_refresh_health)
		var health := actor.attributes.get_vital(&"health") as HealthVital
		if health != null and health.damage_received.is_connected(_on_damage_received):
			health.damage_received.disconnect(_on_damage_received)
	_actor_ref = null
	_setup_complete = false
	remaining = 0.0
	last_damage = 0.0
	hit_count = 0
	if is_instance_valid(hit_effect):
		hit_effect.player.stop()
		hit_effect.visible = false
		hit_effect.play_count = 0
	visible = false

func _exit_tree() -> void:
	unbind_actor()

func _refresh_health(snapshot: Dictionary) -> void:
	if _health.current_health != float(snapshot.hp) or _health.maximum_health != float(snapshot.hpMax):
		_health.set_health(snapshot.hp, snapshot.hpMax, _setup_complete)
	_label.text = "%s / %s" % [_format_value(snapshot.hp), _format_value(snapshot.hpMax)] if snapshot.hp > 0.0 else "已击杀"

func show_hit(data: Dictionary) -> void:
	if not is_instance_valid(_actor):
		return
	global_transform = _actor.global_transform
	# 原版onDamage(0)也先显现；闪避与免疫不走这个分支。
	if not bool(data.get("is_dodged", false)) and not bool(data.get("is_immune", false)):
		_health.show_health()
	last_damage = data.damage
	hit_count += 1
	remaining = 0.65
	_damage.text = "−" + _format_value(last_damage) if last_damage > 0.0 else "格挡"
	if bool(data.get("is_dodged", false)):
		_damage.text = "闪避"
	elif bool(data.get("is_immune", false)):
		_damage.text = "免疫"
	elif float(data.get("shield_absorbed", 0.0)) > 0.0:
		_damage.text = "护盾 %s / 扣血 %s" % [_format_value(data.shield_absorbed), _format_value(last_damage)]
	elif bool(data.get("is_crit", false)):
		_damage.text = "暴击 −" + _format_value(last_damage)
	_damage.position.y = -260.0
	_damage.modulate.a = 1.0
	# 原贴图承担普通/暴击/真实/闪避跳字；文字保留护盾说明与无对应原图的免疫反馈。
	_damage.visible = not original_numbers_enabled or bool(data.get("is_immune", false)) or float(data.get("shield_absorbed", 0.0)) > 0.0
	if original_numbers_enabled:
		_show_original_numbers(data)
	if bool(data.get("has_hit_effect", true)) and not bool(data.get("is_dodged", false)) and not bool(data.get("is_immune", false)):
		hit_effect.play_hit(_actor.animation.get_facing(), hit_effect_unit_scale)

func advance_feedback(delta: float) -> void:
	if not is_instance_valid(_actor):
		return
	global_transform = _actor.global_transform
	_refresh_protection()
	_health.advance_bar(delta, _actor.animation.get_facing())
	_label.visible = show_health_values and _health.visible
	hit_effect.advance_effect(delta)
	if remaining <= 0.0:
		return
	remaining = maxf(0.0, remaining - delta)
	_damage.position.y -= delta * 35.0
	_damage.modulate.a = minf(1.0, remaining / 0.2)
	if remaining <= 0.0:
		_damage.visible = false

func _format_value(value: float) -> String:
	return "%d" % roundi(value)

func _refresh_protection() -> void:
	var protection := _actor.protection
	var show_bar := show_protection_bar and protection.profile != null and protection.profile.enabled and protection.show_protect and _actor.is_alive()
	_protection_bar.visible = show_bar
	_protection_label.visible = show_bar
	if show_bar:
		_protection_bar.max_value = protection.maximum
		_protection_bar.value = clampi(protection.score, 0, protection.maximum)
		_protection_label.text = "保护中" if protection.active else "保护 %d / %d" % [protection.score, protection.maximum]
#endregion
#region 原版跳字分类、独立实例与表现随机流
func _show_original_numbers(data: Dictionary) -> void:
	if bool(data.get("is_immune", false)):
		return
	var random := _actor.session.random
	# 普通/暴击主分支固定(0,-60)，仅闪避分支随机化出生点。
	var local_offset := Vector2(0, -60)
	if bool(data.get("is_dodged", false)):
		local_offset += Vector2(random.random_float(&"damage_numbers") * 20.0, -random.random_float(&"damage_numbers") * 20.0)
	local_offset *= hit_effect_unit_scale
	var world_position := _actor.global_position + local_offset
	# 使用逻辑视口坐标；get_viewport_transform 含窗口拉伸，CanvasLayer 会再次拉伸。
	var screen_position := _actor.get_canvas_transform() * world_position
	screen_position += Vector2(bleed_offset.x * _actor.animation.get_facing(), bleed_offset.y)
	if bool(data.get("is_dodged", false)):
		_spawn_number(0, "dodge", screen_position)
		return
	var normal := maxi(0, int(data.get("normal_damage", data.get("damage", 0.0))))
	var true_damage := maxi(0, int(data.get("true_damage", 0.0)))
	var critical := bool(data.get("is_crit", false))
	if normal > 0:
		var style := "critical" if critical else ("player" if _actor.faction_id == &"player" else "normal")
		_spawn_number(normal, style, screen_position)
	if true_damage > 0:
		var direction := 1.0 if random.random_float(&"damage_numbers") > 0.5 else -1.0
		var true_offset := Vector2(random.random_float(&"damage_numbers") * 60.0 * direction, -10.0 - random.random_float(&"damage_numbers") * 30.0)
		_spawn_number(true_damage, "true_critical" if critical else "true", screen_position + true_offset)

func _spawn_number(value: int, style: String, at: Vector2) -> void:
	# 保持逻辑视口到自定义CanvasLayer/Rows的局部转换。
	number_rows.spawn_number(number_scene, value, style, number_rows.make_canvas_position_local(at))
#endregion
