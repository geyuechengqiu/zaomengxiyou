extends "res://examples/single_attack_demo.gd"
#region 原版伤害预置场景
var sample_index: int = 0
const SAMPLES := ["普通", "暴击", "火抗100", "固定附伤7", "真实伤害50%", "普通护盾50", "闪避", "免疫"]

func _ready() -> void:
	super._ready()
	set_sample(0)
	place_near()

func place_near() -> void:
	# 第四段第一击范围较短，木桩摆在五段均可命中的位置。
	dummies[0].position.x = player.position.x - (210.0 if player.animation.get_facing() < 0 else 290.0)
	dummies[1].position.x = player.position.x + (210.0 if player.animation.get_facing() > 0 else 290.0)

func flip_player() -> void:
	super.flip_player()
	place_near()

func toggle_power() -> void:
	set_sample((sample_index + 1) % SAMPLES.size())

func set_sample(index: int) -> void:
	if player.attack_instance != null and player.attack_instance.active:
		player.cancel_skill()
	sample_index = index
	player.damage_rules.clear()
	player.attributes.set_base_value(&"atk", player.attributes.get_initial_base_value(&"atk", 100.0))
	player.attributes.set_base_value(&"critical", 156.25 if index == 1 else player.attributes.get_initial_base_value(&"critical"))
	player.damage_context = {"random_values": {"calDamage": 0.5, "baojiRatio": 0.5, "calPhysicalDamage": 0.5}}
	for dummy in dummies:
		dummy.damage_rules.clear()
		dummy.attributes.set_base_value(&"hpMax", 500.0)
		dummy.attributes.set_base_value(&"phyDef", 20.0)
		dummy.attributes.set_base_value(&"fireResist", 100.0 if index == 2 else 0.0)
		## 活木桩恢复；已死亡木桩按重置按钮重新加载完整场景。
		if dummy.is_alive():
			(dummy.attributes.get_vital(&"health") as HealthVital).heal(500.0)
		if index == 5:
			dummy.damage_rules.grant_shield(&"demo", 50.0)
		if index == 6:
			dummy.damage_rules.set_source(&"demo", {"fixedDodgeRate": 1.0})
		if index == 7:
			dummy.damage_rules.set_source(&"demo", {"immune": true})
	match index:
		2: player.damage_context.skill_config = {"type": 4}
		3: player.damage_context.skill_config = {"skillCountAdd": [7]}
		4: player.damage_context.skill_config = {"realDamagePercent": 0.5, "realDamageRatio": 1.0}
	$HUD/Panel/Column/Buttons/Power.text = "样例：" + SAMPLES[index]
	message.text = "连按 J 五连击；跑步或跳跃时按 J 使用专属攻击；第四段窗口内新按反向可转身一次。"

func _on_event(id: String, payload: Array) -> void:
	super._on_event(id, payload)
	if payload.size() != 1 or payload[0].get("battle_id") != session.battle_id or payload[0].get("source_entity_id") != player.entity_id:
		return
	if id == "battle.combo.started":
		message.text = "普攻第%d段：再次按 J 预约下一段；长按不自动连招。" % payload[0].combo_step
	elif id == "battle.combo.turned":
		message.text = "已转身：本段保持移动方向，第五段朝%s攻击。" % ("右" if payload[0].facing > 0 else "左")
	elif id == "battle.attack.window_opened":
		var label := "跑动攻击" if player.action_state.current == BattleActionState2D.State.RUN_ATTACK else ("跳跃攻击" if player.action_state.current == BattleActionState2D.State.JUMP_ATTACK else "普攻第%d段" % (player.combo.index + 1))
		message.text = "%s · 第%d个命中事件。" % [label, payload[0].hit_index]
	if id == "battle.attack.hit" and payload.size() == 1 and payload[0].get("source_entity_id") == player.entity_id:
		var data: Dictionary = payload[0]
		message.text = "%s：计算%d → 护盾%d → 扣血%d%s%s" % [SAMPLES[sample_index], roundi(data.calculated_damage), roundi(data.shield_absorbed), roundi(data.actual_hp_loss), " · 闪避" if data.is_dodged else "", " · 暴击" if data.is_crit else ""]

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var parameters: Dictionary = session.damage_strategy.get_level_parameters(player.attributes.current_level)
	info.text = "等级%d · 攻击%d · 状态%s · 命中%d\n暴击评分%d / 换算%d · 左生命%d · 右生命%d" % [player.attributes.current_level, roundi(player.attributes.get_value(&"atk")), player.action_state.get_state_name(), total_hits, roundi(player.attributes.get_value(&"critical")), roundi(parameters.criticalMax), roundi(dummies[0].attributes.get_vital_value(&"health")), roundi(dummies[1].attributes.get_vital_value(&"health"))]
#endregion
