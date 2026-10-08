extends "res://examples/single_attack_demo.gd"
#region 五个技能的预置平台验收场景
const SKILLS: Array[StringName] = [&"sunwukong_skill1", &"sunwukong_skill2", &"sunwukong_skill3", &"sunwukong_skill4", &"sunwukong_skill8"]
const NAMES := ["升龙斩", "烈焰闪", "火眼金睛", "烈焰风暴", "火魔斩"]

func _ready() -> void:
	super._ready()
	for index in range(SKILLS.size()):
		var button := get_node("HUD/Panel/Column/Skills/Skill%d" % (index + 1)) as Button
		button.pressed.connect(func(): player.request_skill_operation(StringName("skill_%d" % (index + 1)), SKILLS[index]))
	$HUD/Panel/Column/Buttons/Power.text = "补满魔法"
	message.text = "Y升龙斩 · U烈焰闪 · I火眼金睛（W/S） · O烈焰风暴（再按重劈） · L火魔斩 · 空格无双表现"

func toggle_power() -> void:
	player.attributes.get_vital(&"mana").set_current_value(player.attributes.get_value(&"mpMax"))

func _process(_delta: float) -> void:
	if not is_instance_valid(player): return
	var descriptions: Array[String] = []
	for index in range(SKILLS.size()):
		var ability := player.abilities.get_ability_instance(SKILLS[index])
		var cooldown := ability.get_feature("CooldownFeature") as CooldownFeature
		var cost := ability.get_feature("CostFeature") as CostFeature
		var mana := cost.costs[0] as BattleSkillManaCost
		descriptions.append("%s MP%d / CD%d毫秒" % [NAMES[index], mana.get_amount(player.abilities, player), ceili(cooldown.get_cooldown_remaining(ability) * 1000.0)])
	info.text = "生命%d/%d · 魔法%d/%d · 命中%d\n%s\n%s" % [player.attributes.get_vital_value(&"health"), player.attributes.get_value(&"hpMax"), player.attributes.get_vital_value(&"mana"), player.attributes.get_value(&"mpMax"), total_hits, " · ".join(descriptions.slice(0,3)), " · ".join(descriptions.slice(3))]
	var wushuang := player.statuses.get_status(&"normal_wushuang_visual")
	if wushuang != null: info.text += " · 无双%d秒" % ceili(wushuang.remaining_duration)

func _on_event(id: String, payload: Array) -> void:
	if payload.size() != 1 or not is_instance_valid(player) or payload[0].get("battle_id") != session.battle_id or payload[0].get("source_entity_id") != player.entity_id: return
	var data: Dictionary = payload[0]
	if id == "battle.attack.hit":
		total_hits += 1
		message.text = "%s · 段%d · 第%d次命中 · 计算%d / 护盾%d / 扣血%d" % [player.abilities.get_ability_instance(data.ability_id).get_definition().ability_name, data.hit_index, data.target_hit_count, data.calculated_damage, data.shield_absorbed, data.actual_hp_loss]
	elif id == "battle.attack.started":
		message.text = "释放 %s；火眼金睛可用W/S转向，烈焰风暴再按O追加重劈。" % player.abilities.get_ability_instance(data.ability_id).get_definition().ability_name
#endregion
