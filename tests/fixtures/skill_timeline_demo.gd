extends "res://tests/fixtures/single_attack_demo.gd"
#region 阶段7预置场景演示
func _ready() -> void:
	super._ready()
	$HUD/Panel/Column/Buttons/Cancel.pressed.connect(func(): player.cancel_skill())
	message.text = "J 释放三段技能；第28—38帧按J派生普攻，可提前8帧缓存。"

func _on_event(id: String, payload: Array) -> void:
	if not is_instance_valid(player) or payload.size() != 1 or payload[0].get("battle_id") != session.battle_id or payload[0].get("source_entity_id") != player.entity_id:
		return
	var data: Dictionary = payload[0]
	match id:
		"battle.attack.started": message.text = "技能起手：前摇 → 三个独立命中段 → 派生窗口 → 后摇。"
		"battle.attack.hit":
			total_hits += 1
			message.text = "第%d段：倍率 %.0f%% · 附伤 %.0f · 实际扣血 %.0f · 击退 %.0f" % [int(data.get("hit_index", 1)), float(data.get("damage_multiplier", 1.0)) * 100.0, float(data.get("fixed_damage", 0.0)), float(data.damage), float(data.get("knockback_speed", 0.0))]
		"battle.attack.finished": message.text = "释放结束：%s · 命中%d次；旧窗口、对象和待执行事件已清理。" % [data.reason, data.hit_count]

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	var skill := player.abilities.get_ability_instance(&"sunwukong_timeline_attack")
	var cooldown := skill.get_feature("CooldownFeature") as CooldownFeature if skill != null else null
	var remaining := cooldown.get_cooldown_remaining(skill) if cooldown != null else 0.0
	info.text = "状态 %s · 阶段 %s · 攻击 %.0f · 魔法 %.0f · 冷却 %.0fms\n左木桩 %.0f / 500 · 右木桩 %.0f / 500 · 命中 %d%s" % [player.action_state.get_state_name(), player.attack_instance.phase if player.attack_instance != null else &"idle", player.attributes.get_value(&"atk"), player.attributes.get_vital_value(&"mana"), remaining * 1000.0, dummies[0].attributes.get_vital_value(&"health"), dummies[1].attributes.get_vital_value(&"health"), total_hits, "（暂停）" if session.clock.paused else ""]
#endregion
