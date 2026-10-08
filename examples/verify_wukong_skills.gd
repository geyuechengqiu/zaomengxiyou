extends Node
#region 原版五技能、真实场景与命中记录
var demo: Node2D
var player: BattleEntity2D
var target: BattleEntity2D
var session: BattleSession
var hits: Array[Dictionary] = []
var failures: Array[String] = []
var checks: int = 0
const SKILLS: Array[StringName] = [&"sunwukong_skill1", &"sunwukong_skill2", &"sunwukong_skill3", &"sunwukong_skill4", &"sunwukong_skill8"]

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _ready() -> void:
	CoreSystem.event_bus.event_pushed.connect(_event)
	await _fresh()
	_verify_resources()
	_verify_effect_scaling()
	await _verify_skills()
	await _verify_dash()
	await _verify_ray()
	await _verify_follow_up()
	await _verify_tail_and_native_input()
	await _verify_costs_air_and_cancel()
	await _verify_instance_isolation()
	await _verify_original_reactions()
	CoreSystem.event_bus.event_pushed.disconnect(_event)
	demo.free()
	if failures.is_empty():
		print("PASS Wukong basic skills: %d checks; original five skills/AB/MP/CD, sky/cancel, dash sweep/wall, aimed five-hit ray, spin follow-up, independent fire8 slam and low-FPS replay" % checks)
		get_tree().quit()
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)

func _event(id: String, payload: Array) -> void:
	if id == "battle.attack.hit" and payload.size() == 1 and is_instance_valid(session) and payload[0].get("battle_id") == session.battle_id and payload[0].get("source_entity_id") == player.entity_id:
		hits.append(payload[0].duplicate(true))

func _paths(root: Node) -> Array[String]:
	var paths: Array[String] = []
	for child in root.get_children():
		paths.append(String(root.get_path_to(child)))
		for path in _paths(child): paths.append("%s/%s" % [child.name, path])
	return paths

func _fresh() -> void:
	if is_instance_valid(demo): demo.free()
	demo = load("res://examples/wukong_skills_demo.tscn").instantiate()
	demo.enable_player_controls = false
	var authored := _paths(demo)
	add_child(demo)
	_check(_paths(demo) == authored, "技能和特效复用全部预置节点")
	player = demo.player
	target = demo.dummies[1]
	session = demo.session
	session.set_physics_process(false)
	player.attributes.set_base_value(&"mpMax", 10000)
	player.attributes.get_vital(&"mana").set_current_value(10000)
	player.damage_context = {"random_values": {"calDamage": 0.5, "baojiRatio": 1.0, "calPhysicalDamage": 0.5}}
	for dummy in demo.dummies:
		dummy.super_armor = true
		dummy.reaction_profile = dummy.reaction_profile.duplicate(true)
		dummy.reaction_profile.armor_blocks_displacement = true
		dummy.global_position = Vector2(-3000, 650)
	await _step(10)
	hits.clear()

func _step(ticks: int, delta: float = 1.0/60.0) -> void:
	for tick in range(ticks):
		await get_tree().physics_frame
		session.advance_physics(delta)

func _place(x: float = 450.0) -> void:
	target.global_position = Vector2(x, 650)
	target.velocity = Vector2.ZERO
	target.motion.clear_impulse()

func _timeline(id: StringName) -> BattleFrameTimelineFeature:
	return player.abilities.get_ability_instance(id).get_feature("BattleFrameTimelineFeature") as BattleFrameTimelineFeature

func _verify_resources() -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/sunwukong/original_source.json"))
	for index in range(SKILLS.size()):
		var id := SKILLS[index]
		var key := String(id).trim_prefix("sunwukong_")
		var source: Dictionary = original.skills[key]
		var timeline := _timeline(id)
		var ability := player.abilities.get_ability_instance(id)
		var cost := ability.get_feature("CostFeature") as CostFeature
		var mana := cost.costs[0] as BattleSkillManaCost
		_check(timeline.is_configuration_valid(), "原版时间轴有效:" + key)
		_check(mana.get_amount(player.abilities, player) == float(str(source.consumeMP).split(";")[1]), "原版一级MP:" + key)
		_check(player.animation.get_action_duration(StringName(key)) > 0.0, "编辑器预置动作:" + key)
		_check(player.operations.ability_slots[StringName("skill_%d" % (index+1))] == id, "槽位映射:" + key)
		_check(timeline.can_use_in_air == bool(source.canUseInSKy), "空中许可:" + key)
		_check(session.damage_strategy.get_skill_parameters(id).source_skill_id == source.id, "独立原版伤害入口:" + key)
	_check(_timeline(&"sunwukong_skill8").attack_segments[1].sub_skill_id == &"sunwukong_skill8_slam", "火魔斩砸地使用独立子技能")
	_check(_timeline(&"sunwukong_skill8").attack_segments[1].start_frame == 28, "火魔斩砸地不提前启用零AB")
	_check(player.animation.get_node("AttackEffects/SkillPrimary") is SpineSprite, "原版技能特效预置SpineSprite")
	_check(player.attack_hitbox.get_parent().get_children().filter(func(n): return n is BattleHitbox2D).size() == 1, "所有攻击继续复用单个判定框")
#endregion

#region 特效源坐标、父层唯一缩放及左右镜像验收
func _verify_effect_scaling() -> void:
	var effect := player.animation.get_node("AttackEffects/SkillPrimary") as Node2D
	for action: StringName in [&"skill1", &"skill2", &"skill3", &"skill4", &"skill4_1", &"skill8"]:
		var expected := Vector2(1200.0/68.0,1) if action == &"skill3" else (Vector2(1.2,1) if action == &"skill4" else Vector2.ONE)
		for direction in [1,-1]:
			player.animation.set_facing(direction)
			player.animation.play_action(action,true)
			var sample_time := 0.5 if action == &"skill4" else 0.3
			player.animation.advance_animation(sample_time)
			_check(effect.visible and effect.scale.is_equal_approx(expected), "原版子特效比例:"+String(action)+str(direction))
			_check(is_equal_approx(effect.global_transform.x.length(),expected.x*2) and is_equal_approx(effect.global_transform.y.length(),expected.y*2), "父级只应用一次显示比例:"+String(action)+str(direction))
			if action in [&"skill2", &"skill4"]:
				var body := player.animation.get_node("SpineVisual") as SpineSprite
				var duration := body.get_skeleton_data_res().find_animation(String(action)).get_duration()
				_check(absf(body.get_animation_state().get_track(0).get_track_time()-fmod(sample_time,duration))<0.00001, "编辑器原生循环标记重建后仍准确重放身体:"+String(action)+str(direction))
			if action == &"skill3":
				var tip := player.animation.get_node("AttackEffects/BeamEnd") as Node2D
				_check(effect.global_position.distance_to(player.animation.to_global(Vector2(114*direction,-86))) < 0.01, "射线发射点贴合角色且随朝向镜像")
				_check(is_equal_approx(tip.global_position.distance_to(effect.global_position),2400), "编辑预览射线终点与实际长度一致")
	player.animation.set_facing(1)
	player.animation.play_action(&"idle",true)
#endregion

#region 同配置角色技能、MP、CD、瞄准与取消隔离
func _verify_instance_isolation() -> void:
	await _fresh()
	var other := load("res://data/battle2d/sunwukong_2d.tscn").instantiate() as BattleEntity2D
	other.scene_definition_id = &"孙悟空"
	other.get_node("PlayerOperations").enabled = false
	other.position = Vector2(700, 650)
	demo.get_node("BattleSession/Actors").add_child(other)
	await _step(2)
	other.attributes.set_base_value(&"mpMax", 10000)
	other.attributes.get_vital(&"mana").set_current_value(10000)
	player.damage_rules.skill_levels[&"sunwukong_skill3"] = 2
	player.skill_aim_axis = -1
	other.skill_aim_axis = 1
	_check(player.try_activate_skill(&"sunwukong_skill3") and other.try_activate_skill(&"sunwukong_skill3"), "同配置双悟空同时释放射线")
	await _step(20)
	_check(player.attack_instance != other.attack_instance, "技能释放实例独立")
	_check(player.attack_instance.aim_degrees < 0 and other.attack_instance.aim_degrees > 0, "同时施放的射线瞄准独立")
	var left_ability := player.abilities.get_ability_instance(&"sunwukong_skill3")
	var right_ability := other.abilities.get_ability_instance(&"sunwukong_skill3")
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/sunwukong/original_source.json")).skills.skill3
	var amounts := str(source.consumeMP).split(";")
	_check(player.attributes.get_vital_value(&"mana") == 10000-float(amounts[2]) and other.attributes.get_vital_value(&"mana") == 10000-float(amounts[1]), "技能等级与MP按各自实体读取")
	var left_cd := left_ability.get_feature("CooldownFeature") as CooldownFeature
	var right_cd := right_ability.get_feature("CooldownFeature") as CooldownFeature
	_check(not is_equal_approx(left_cd.get_cooldown_remaining(left_ability), right_cd.get_cooldown_remaining(right_ability)), "按等级提交的冷却各自独立")
	var other_cast := other.attack_instance
	player.cancel_skill()
	_check(other_cast.active and other.attack_instance == other_cast and other.animation.get_current_action() == &"skill3", "取消角色A不清除角色B的技能和动画")
	await _step(65)
	_check(not other_cast.active, "未取消角色B完成自己的剩余时间轴")
#endregion

#region 命中次数、原版结算、低帧率与动画清理
func _verify_skills() -> void:
	for id in [&"sunwukong_skill1", &"sunwukong_skill3", &"sunwukong_skill4", &"sunwukong_skill8"]:
		await _fresh()
		_place(650 if id == &"sunwukong_skill3" else 450)
		var amount := player.attributes.get_vital_value(&"mana")
		_check(player.try_activate_skill(id), "技能起手:" + String(id))
		var attack := player.attack_instance
		await _step(1)
		_check(attack.committed and player.attributes.get_vital_value(&"mana") < amount, "仅提交一次MP:" + String(id))
		if id != &"sunwukong_skill3": _check(TagManager.has_tag(player, &"state.super_armor"), "原版技能霸体:" + String(id))
		if id == &"sunwukong_skill8": _check(player.damage_rules.get_number(&"dmgRate") == 50.0, "火魔斩原版受伤增减幅50")
		await _step(110)
		var expected := 1 if id == &"sunwukong_skill1" else (6 if id == &"sunwukong_skill8" else 5)
		_check(hits.size() == expected, "原版预期命中%d/%d:%s" % [hits.size(),expected,id])
		_check(not attack.active and attack.windows.is_empty(), "结束清理命中窗口:" + String(id))
		_check(player.action_state.current == BattleActionState2D.State.IDLE, "动作结束恢复待机:" + String(id))
		for name in ["SkillPrimary","SkillSecondary","BeamEnd"]:
			_check(not player.animation.get_node("AttackEffects/" + name).visible, "结束没有技能特效残留:" + String(id)+name)
		_check(not TagManager.has_tag(player, &"state.super_armor"), "霸体按原版时间结束:" + String(id))
		_check(player.damage_rules.get_number(&"dmgRate") == 0.0, "受伤增减幅按时恢复:" + String(id))
		if id == &"sunwukong_skill8" and hits.size() == 6:
			_check(hits[-1].sub_skill_id == &"sunwukong_skill8_slam" and hits[-1].source_frame >= 28, "末段独立子技能且不提前")
			_check(hits[-1].calculated_damage > hits[0].calculated_damage, "砸地高伤害使用原版独立倍率和附伤")
			for index in range(1,5):
				_check(absf(hits[index].sample_time - hits[index-1].sample_time - 0.18) < 0.00001, "火魔斩按每目标0.18秒时限结算，不量化成0.2秒")
	await _fresh()
	_place()
	_check(player.try_activate_skill(&"sunwukong_skill8"), "低帧率火魔斩起手")
	await _step(1,1.5)
	_check(hits.size() == 6, "单tick跨43帧仍有5连斩+砸地")
	_check(not player.attack_instance.active, "低帧率及时结束")

func _verify_dash() -> void:
	await _fresh()
	_place(900)
	var origin := player.global_position.x
	_check(player.try_activate_skill(&"sunwukong_skill2"), "原版冲刺起手")
	await _step(1,0.5)
	_check(absf(player.global_position.x-origin-400.0)<1.0, "0.5秒按800速度扫掠400像素")
	_check(hits.size() == 1, "低帧率冲刺途中进入范围也命中一次")
	await _fresh()
	player.global_position.x = 1170
	_check(player.try_activate_skill(&"sunwukong_skill2"), "靠墙冲刺")
	await _step(1,0.5)
	_check(player.global_position.x < 1280, "冲刺不穿墙")
	await _fresh()
	player.animation.set_facing(-1)
	origin = player.global_position.x
	_check(player.try_activate_skill(&"sunwukong_skill2"), "左冲刺起手")
	await _step(1,0.5)
	_check(absf(player.global_position.x-origin+400)<1, "冲刺位移跟随朝向")

func _verify_ray() -> void:
	await _fresh()
	var bone := (player.animation.get_node("SpineVisual") as SpineSprite).get_skeleton().find_bone("mz_头2")
	var base_rotation := bone.get_pose().get_rotation()
	player.skill_aim_axis = -1
	_check(player.try_activate_skill(&"sunwukong_skill3"), "火眼金睛可转向")
	await _step(6)
	_check(player.attack_instance.aim_degrees == 0 and absf(bone.get_pose().get_rotation()-base_rotation)<0.001, "第5帧射线产生前不提前转头和累积瞄准")
	await _step(1,0.6)
	_check(is_equal_approx(player.attack_instance.aim_degrees,-30), "60度每秒、最大仰角30")
	var shape := player.attack_hitbox.get_node("CollisionShape2D") as CollisionShape2D
	_check(absf(shape.rotation-deg_to_rad(-30))<0.001, "射线判定旋转与视觉一致")
	var visual := player.animation.get_node("AttackEffects/SkillPrimary") as Node2D
	_check(absf(visual.rotation-shape.rotation)<0.001, "射线视觉与单个判定框同角度")
	var tip := player.animation.get_node("AttackEffects/BeamEnd") as Node2D
	_check(tip.position.distance_to(visual.position + Vector2(1200,0).rotated(shape.rotation))<1, "射线末端使用素材局部长度随转向")
	var root := player.animation.get_node("AttackEffects") as Node2D
	_check(visual.position.is_equal_approx(Vector2(57,-43)), "射线原点使用原素材坐标，不重复乘2")
	_check(visual.global_position.distance_to(player.animation.to_global(Vector2(114,-86))) < 0.01, "射线世界原点只应用一次显示比例")
	_check(absf(tip.global_position.distance_to(visual.global_position)-2400.0) < 0.01, "世界射线长度只应用一次2倍比例")
	_check(root.scale.is_equal_approx(Vector2(2,2)) and visual.scale.is_equal_approx(Vector2(1200.0/68.0,1)), "射线长度缩放与显示缩放各应用一次")
	_check(absf(bone.get_pose().get_rotation()-base_rotation-30)<0.001, "头部仅叠加一次绝对瞄准偏移")
	for repeat_index in range(60): player.animation.apply_skill_aim(_timeline(&"sunwukong_skill3"),-30)
	_check(absf(bone.get_pose().get_rotation()-base_rotation-30)<0.001, "重复采样60次头部不累积旋转")
	player.skill_aim_axis = 0
	await _step(8)
	_check(absf(bone.get_pose().get_rotation()-base_rotation-30)<0.001, "松开瞄准后持续播放不会扭头")
	player.cancel_skill()
	player.skill_aim_axis = 0
	await _step(1)
	_check(not visual.visible and not tip.visible, "取消射线同时清理末端与光柱")
	_check(absf(bone.get_pose().get_rotation()-base_rotation)<0.001, "取消射线撤销头部偏移")
	await _fresh()
	player.animation.set_facing(-1)
	bone = (player.animation.get_node("SpineVisual") as SpineSprite).get_skeleton().find_bone("mz_头2")
	base_rotation = bone.get_pose().get_rotation()
	player.skill_aim_axis = 1
	_check(player.try_activate_skill(&"sunwukong_skill3"), "俯角测试起手")
	await _step(1,0.45)
	_check(is_equal_approx(player.attack_instance.aim_degrees,15), "俯角最多15度")
	_check(absf(bone.get_pose().get_rotation()-base_rotation+15)<0.001, "左向头骨使用局部瞄准角，镜像不额外反转")
	await _step(1,35.0/30.0-player.attack_instance.elapsed)
	_check(player.attack_instance.active and absf(bone.get_pose().get_rotation()-base_rotation)<0.001, "第35帧射线销毁即恢复头部，不等待身体第37帧")

func _verify_follow_up() -> void:
	await _fresh()
	_place()
	_check(player.request_skill_operation(&"skill_4", &"sunwukong_skill4"), "操作请求进入风暴")
	await _step(10)
	var mana := player.attributes.get_vital_value(&"mana")
	_check(player.request_skill_operation(&"skill_4", &"sunwukong_skill4"), "再按一次O预约追加重劈")
	await _step(1)
	_check(player.attack_instance.ability_id == &"sunwukong_skill4_1", "追加切换独立GAS子技能")
	await _step(50)
	_check(player.attributes.get_vital_value(&"mana") == mana, "重劈不重复消耗父技能MP")
	_check(hits.any(func(row): return row.ability_id == &"sunwukong_skill4_1"), "重劈第7帧真实命中")
	_check(player.action_state.current == BattleActionState2D.State.IDLE, "重劈后待机")

func _verify_tail_and_native_input() -> void:
	await _fresh()
	_place()
	_check(player.try_activate_skill(&"sunwukong_skill8"), "原版尾帧测试")
	await _step(86)
	_check(player.action_state.current == BattleActionState2D.State.IDLE and not player.attack_instance.active, "第43帧结束战斗动作，不等待46帧特效")
	var effect := player.animation.get_node("AttackEffects/SkillSecondary") as SpineSprite
	_check(effect.visible, "原版非随状态特效保留最后3帧")
	var count := hits.size()
	await _step(4)
	_check(effect.visible and hits.size() == count, "尾帧仅显示，不重复结算伤害")
	await _step(3)
	_check(not effect.visible, "第46帧准时清理尾帧")
	for index in range(SKILLS.size()):
		await _fresh()
		player.operations.enabled = true
		var key := InputEventKey.new()
		key.keycode = [KEY_Y,KEY_U,KEY_I,KEY_O,KEY_L][index]
		key.physical_keycode = key.keycode
		key.pressed = true
		player.operations.controller.process_native_event(key)
		key.pressed = false
		player.operations.controller.process_native_event(key)
		await _step(1)
		_check(player.attack_instance != null and player.attack_instance.ability_id == SKILLS[index], "实际默认键转操作意图并释放:"+String(SKILLS[index]))
		var cast := player.attack_instance
		await _step(1)
		_check(player.attack_instance == cast, "短按只生成一次技能实例:"+String(SKILLS[index]))
	await _fresh()
	player.attributes.get_vital(&"mana").set_current_value(30)
	_check(not player.try_activate_skill(&"sunwukong_skill1", {"skill_level": 3}), "显式技能等级快照在起手校验消耗71MP")
	_check(player.attributes.get_vital_value(&"mana") == 30, "显式等级消耗校验失败不扣魔法")
#endregion

#region MP/CD等级、空中规则、普攻打断、暂停和取消
func _verify_costs_air_and_cancel() -> void:
	await _fresh()
	player.attributes.get_vital(&"mana").set_current_value(21)
	_check(not player.try_activate_skill(&"sunwukong_skill1"), "魔法不足不释放")
	_check(player.action_state.current == BattleActionState2D.State.IDLE, "消耗失败不锁动作")
	player.attributes.get_vital(&"mana").set_current_value(10000)
	player.damage_rules.skill_levels[&"sunwukong_skill1"] = 2
	_check(player.try_activate_skill(&"sunwukong_skill1"), "二级升龙斩")
	await _step(1)
	_check(player.attributes.get_vital_value(&"mana") == 9956, "二级消耗原版44MP")
	var cooldown := player.abilities.get_ability_instance(&"sunwukong_skill1").get_feature("CooldownFeature") as CooldownFeature
	_check(absf(cooldown.get_cooldown_remaining(player.abilities.get_ability_instance(&"sunwukong_skill1"))-2.3)<0.02, "二级原版冷却2.3秒")
	player.cancel_skill()
	_check(not player.try_activate_skill(&"sunwukong_skill1"), "取消仍保留已提交冷却")
	await _fresh()
	_check(player.request_attack(), "普攻起手")
	_check(player.request_skill_operation(&"skill_1", &"sunwukong_skill1"), "技能按原版breakActionNames打断普攻")
	_check(not player.combo.is_active() and player.attack_instance.ability_id == &"sunwukong_skill1", "普攻预约和窗口全部清理")
	await _fresh()
	_check(player.try_jump(), "空中施放夹具起跳")
	_check(player.try_activate_skill(&"sunwukong_skill1"), "原版升龙斩可空中施放")
	player.cancel_skill()
	_check(not player.try_activate_skill(&"sunwukong_skill3"), "火眼金睛仅地面施放")
	for id in [&"sunwukong_skill2",&"sunwukong_skill4",&"sunwukong_skill8"]:
		await _fresh()
		_check(player.try_jump() and player.try_activate_skill(id), "原版空中施放:"+String(id))
		await _step(4)
		var cast := player.attack_instance
		var time := cast.elapsed
		session.set_paused(true)
		await _step(6)
		_check(cast.elapsed == time, "暂停停止素材技能时钟:"+String(id))
		session.set_paused(false)
		player.cancel_skill()
		await _step(50)
		_check(not cast.active and cast.windows.is_empty(), "取消清理旧判定:"+String(id))
		_check(hits.is_empty(), "取消之后旧技能不再命中:"+String(id))
	await _fresh()
	_check(player.try_activate_skill(&"sunwukong_skill8"), "死亡清理夹具")
	await _step(3)
	player.attributes.get_vital(&"health").set_current_value(0)
	await _step(1)
	_check(player.action_state.current == BattleActionState2D.State.DEAD and not player.attack_instance.active, "死亡最高优先级清理技能")
	_check(player.statuses.get_active_statuses().is_empty(), "死亡移除技能霸体和受伤增减幅")
#endregion

#region 原版TargetMove物理单位、真实击飞、双侧吸附与霸体
func _verify_original_reactions() -> void:
	await _fresh()
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills/sunwukong/original_source.json"))
	var body_ratio := float(source.physics.source_fps)*float(source.physics.nape_step)
	var gravity := float(source.physics.gravity)*body_ratio*body_ratio*float(source.physics.display_scale)
	for key in [&"skill1",&"skill2",&"skill3",&"skill4",&"skill4_1",&"skill8"]:
		var timeline := _timeline(StringName("sunwukong_"+key))
		for index in range(timeline.attack_segments.size()):
			var original: Dictionary = source.skills[String(key)].param.s[index if key == &"skill8" else (1 if key == &"skill3" else 0)]
			var move := str(original.targetMove).split(";")
			var segment := timeline.attack_segments[index]
			_check(is_equal_approx(segment.launch_speed,float(move[1])*body_ratio*2), "原版竖向速度直接写入Nape，独立换算:"+String(key)+str(index))
			_check(is_equal_approx(segment.knockback_speed,float(move[0])*2) and is_equal_approx(segment.knockback_duration,float(original.stiff)), "原版横向速度和持续时间:"+String(key)+str(index))
			_check(segment.reset_vertical_velocity and is_equal_approx(segment.reaction_gravity,gravity), "原版重力与覆写竖向速度:"+String(key)+str(index))
	target.super_armor = false
	_place()
	await _step(2)
	var floor_y := target.global_position.y
	_check(player.try_activate_skill(&"sunwukong_skill1"), "无霸体目标实际升龙斩")
	await _step(7)
	_check(hits.size()==1 and hits[0].displacement_applied and hits[0].reaction_applied, "升龙斩命中经过真实动作和运动裁决")
	_check(target.action_state.current == BattleActionState2D.State.LAUNCHED and target.velocity.y < -1000, "升龙斩1200世界速度实际击飞")
	_check(is_equal_approx(target.motion.reaction_gravity,1980), "击飞采用原版110重力转换后的1980")
	await _step(14)
	_check(target.global_position.y < floor_y-150 and not target.motion.grounded, "目标真实离地，不只播放受伤动画")
	await _step(100)
	_check(target.motion.grounded and target.motion.reaction_gravity == -1, "落地后恢复目标常规运动重力")
	await _fresh()
	var left: BattleEntity2D = demo.dummies[0]
	for dummy in demo.dummies:
		dummy.super_armor = false
		dummy.velocity = Vector2.ZERO
		dummy.motion.clear_impulse()
	left.global_position = Vector2(player.global_position.x-260,650)
	target.global_position = Vector2(player.global_position.x+260,650)
	await _step(2)
	var left_start := left.global_position
	var right_start := target.global_position
	_check(player.try_activate_skill(&"sunwukong_skill8"), "真实双侧火魔斩")
	await _step(1)
	_check(left.motion.impulse_speed == 300 and target.motion.impulse_speed == -300, "原版attackedMoveDir=2结合负150，两侧均向悟空吸附")
	_check(left.velocity.y < -300 and target.velocity.y < -300, "原版火魔斩60竖向值转换为360浮空")
	await _step(6)
	_check(left.global_position.x > left_start.x+25 and target.global_position.x < right_start.x-25, "两侧目标真实向中心移动")
	_check(left.global_position.y < left_start.y-20 and target.global_position.y < right_start.y-20, "吸附连打同时真实挑起目标")
	await _step(90)
	_check(hits.size()==12 and hits.filter(func(row): return row.sub_skill_id==&"sunwukong_skill8_slam").size()==2, "运动中的两侧目标各5连打与1次独立砸地")
	await _fresh()
	_place()
	var stationary := target.global_position
	_check(player.try_activate_skill(&"sunwukong_skill1"), "霸体目标升龙斩")
	await _step(15)
	_check(target.super_armor and hits.size()==1 and not hits[0].displacement_applied and target.global_position.distance_to(stationary)<1, "原版superArmor仍抵抗TargetMove，不绕过目标策略")
#endregion
