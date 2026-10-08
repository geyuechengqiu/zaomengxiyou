extends "res://examples/original_damage_demo.gd"
#region 预置控件与公共Buff入口
const BASIC := {"AttackUp": &"attack_up", "Slow": &"slow", "Stun": &"stun", "Poison": &"poison", "Shield": &"shield", "Invulnerable": &"invulnerable", "Armor": &"super_armor", "Reflection": &"reflection", "LifeSteal": &"lifesteal"}
@onready var target_select: OptionButton = $HUD/BuffPanel/Column/Target
@onready var buff_info: Label = $HUD/BuffPanel/Column/StatusScroll/Status

func _ready() -> void:
	super._ready()
	for name in BASIC:
		$HUD/BuffPanel/Column/Buttons.get_node(NodePath(name)).pressed.connect(apply_selected.bind(BASIC[name]))
	$HUD/BuffPanel/Column/Buttons/Clear.pressed.connect(clear_selected)
	$HUD/BuffPanel/Column/Buttons/Passives.pressed.connect(enable_passives)

func set_sample(index: int) -> void:
	if is_instance_valid(player):
		for actor in session.get_entities():
			actor.statuses.clear_statuses(&"sample_changed")
	super.set_sample(index)

func get_selected_target() -> BattleEntity2D:
	return [player, dummies[0], dummies[1]][target_select.selected] as BattleEntity2D

func apply_selected(id: StringName) -> void:
	var target := get_selected_target()
	var instance := target.apply_status_definition(id, player)
	message.text = "施加 %s：%s" % [id, "成功" if instance != null else "目标死亡或免疫，未施加"]

func clear_selected() -> void:
	get_selected_target().statuses.clear_statuses(&"dispelled")

func enable_passives() -> void:
	for id in [&"passive_cast_attack", &"passive_hit_poison", &"passive_received_attack", &"passive_low_health_shield", &"passive_kill_heal"]:
		player.apply_status_definition(id, player)
	message.text = "悟空已接入释放加攻、命中中毒、受击加攻、生命30%护盾和击杀回复的组合被动验收。"

func _process(delta: float) -> void:
	super._process(delta)
	if not is_instance_valid(target_select) or not is_instance_valid(player):
		return
	var target := get_selected_target()
	var rows: Array[String] = []
	for instance in target.statuses.get_active_statuses():
		rows.append("%s ×%d %s" % [instance.status_data.status_display_name, instance.stacks, "%dms" % ceili(instance.remaining_duration * 1000.0) if instance.remaining_duration >= 0.0 else "永久"])
	buff_info.text = "攻击%d · 移速%d · 护盾%d\n%s" % [roundi(target.attributes.get_value(&"atk")), roundi(target.attributes.get_value(&"walkSpeed")), roundi(target.damage_rules.get_shield_total()), "\n".join(rows) if not rows.is_empty() else "无Buff"]
#endregion
