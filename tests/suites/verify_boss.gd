extends Node
#region 真实场景与固定物理时钟
var scene: Node2D
var session: BattleSession
var player: BattleEntity2D
var boss: BattleEntity2D
var controller: BattleBossController2D
var feedback: BattleBossFeedback2D
var rows: Array[Dictionary] = []
var failures: Array[String] = []
var checks: int = 0

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _ready() -> void:
	CoreSystem.event_bus.event_pushed.connect(_event)
	await _fresh()
	_verify_source()
	await _verify_jump_height()
	await _verify_melee()
	await _verify_notes()
	await _verify_low_fps()
	await _verify_wall()
	await _verify_wall_no_contact_damage()
	await _verify_lead_control()
	await _verify_phases()
	await _verify_summons()
	await _verify_protection_and_cleanup()
	await _verify_playable_level()
	CoreSystem.event_bus.event_pushed.disconnect(_event)
	scene.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS stage 13 Boss: %d checks; original 3 skills/fan notes/wall, Core AI/GAS, announcement/attack timing, low FPS, stages/conditions/summons, protection/UI/audio/clocks, death/cancel/cleanup and actual Wukong playable first level" % checks)
		get_tree().quit()
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)

func _fresh(with_boss: bool = true) -> void:
	if is_instance_valid(scene): scene.free()
	scene = load("res://game/levels/biyujing.tscn").instantiate()
	scene.enable_player_controls = false
	add_child(scene)
	session = scene.session
	session.set_physics_process(false)
	player = scene.player
	feedback = session.presentation.get_node("BossFeedback") as BattleBossFeedback2D
	feedback.sound_enabled = false
	if with_boss:
		scene.flow.stop()
		boss = session.spawn_entity_2d("monsters", &"巨石灵君", Vector2(900,1056))
		controller = boss.ai_controller as BattleBossController2D
		controller.enabled = false
		controller.boss_profile = controller.boss_profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
		player.global_position = Vector2(1300,1056)
		player.attributes.set_base_value(&"hpMax", 100000)
		player.attributes.get_vital(&"health").set_current_value(100000)
		player.super_armor = true
	else:
		boss = null
		controller = null
	await _step()
	rows.clear()

func _step(delta: float = 1.0/60) -> void:
	await get_tree().physics_frame
	session.advance_physics(delta)

func _event(id: String, payload: Array) -> void:
	if payload.size() != 1 or not payload[0] is Dictionary or not is_instance_valid(session) or payload[0].get("battle_id") != session.battle_id: return
	var row: Dictionary = payload[0].duplicate()
	row["event"] = id
	rows.append(row)

func _events(id: String, actor: StringName = &"") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in rows:
		if row.event == id and (actor.is_empty() or row.get("source_entity_id") == actor): result.append(row)
	return result

func _active_objects(kind: String = "") -> Array[BattleBossWorldObject2D]:
	var result: Array[BattleBossWorldObject2D] = []
	for object: BattleBossWorldObject2D in controller.objects.get_children():
		if object.active and (kind.is_empty() or object.definition.kind == kind): result.append(object)
	return result

func _move(actor: BattleEntity2D, x: float) -> void:
	actor.global_position = Vector2(x,1056)
	actor.velocity = Vector2.ZERO
	actor.motion.clear_impulse()
	actor.move_axis = 0
	actor.running = false
#endregion
#region 原版数据与三个技能的素材帧
func _verify_source() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/jushi_lingjun/original_boss.json"))
	_check(data.monster.skill2 == 2001110 and data.monster.skill3 == 2001120 and data.monster.protectPoint == 25000, "源Boss技能与保护满值准确")
	_check(data.animations.skill1 == 38 and data.animations.skill2 == 44 and data.animations.skill3 == 30, "三动作原30FPS时长")
	_check(controller.boss_profile.phases.is_empty() and not data.scope.monster_summoning, "原版普通巨石灵君没有伪造阶段或召唤")
	_check(boss.attributes.get_value(&"soilResist") == 10 and boss.attributes.get_value(&"fireResist") == -10, "原版土抗10、火抗-10")
	_check(controller.objects.get_child_count() == 8 and boss.attack_hitbox != null, "五弹道三石墙完整预置；人物仍用单一攻击框")
	_check(feedback.bar.visible and feedback.count_label.text == "X3" and feedback.health_label.text == "1167 / 1167", "全场Boss血条显示整数与三条血量")
	_check(not boss.feedback._health.visible and not boss.feedback._protection_bar.visible, "Boss使用公共专属血条，头顶通用条不重复显示")
	_check(feedback.music.stream != null and feedback.hit_audio.stream != null and feedback.victory_sound != null, "原音乐、命中与胜负声音已导出绑定")
	_check(feedback.music.bus == &"Music" and feedback.hit_audio.bus == &"SFX", "预置播放器复用Core音量分类总线")
	_check(scene.camera.offset.is_finite() and scene.camera.offset == Vector2.ZERO, "无镜头反馈时保持有限坐标，不计算sin(INF)")
	var invalid := controller.boss_profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as BattleBossProfile
	invalid.skills.append(invalid.skills[0])
	_check(not invalid.is_valid(), "重复技能配置拒绝加载")

func _verify_jump_height() -> void:
	for delta in [1.0 / 60.0, 1.0 / 30.0, 0.2]:
		_move(boss, 900)
		boss.action_state.enter(BattleActionState2D.State.IDLE)
		await _step()
		var start_y := boss.global_position.y
		_check(boss.try_jump(), "Boss使用同一动作入口起跳")
		var top_y := start_y
		var elapsed := 0.0
		while elapsed < 0.8:
			await _step(delta)
			elapsed += delta
			top_y = minf(top_y, boss.global_position.y)
		_check(start_y - top_y > 77 and start_y - top_y < 98, "Boss正常与低帧率跳高一致")
		_check(boss.motion.grounded and boss.motion.jumps_used == 0 and absf(boss.global_position.y - start_y) < 0.1, "Boss起跳后回到地面")
	await _fresh()

func _verify_melee() -> void:
	_move(player,1050)
	var before := player.attributes.get_vital_value(&"health")
	_check(boss.try_activate_skill(&"jushi_lingjun_skill1"), "普通技能通过真实GAS与Core动作启动")
	await _step(14.0/30)
	_check(player.attributes.get_vital_value(&"health") == before and boss.animation.get_current_action() == &"attack_1", "14帧只有动画，没有提前伤害；HP%d/%d，动作%s，状态%d" % [player.attributes.get_vital_value(&"health"), before, boss.animation.get_current_action(), boss.action_state.current])
	await _step(1.01/30)
	_check(player.attributes.get_vital_value(&"health") < before, "原AB第15帧实际命中")
	await _step(0.5)
	_check(_events("battle.attack.hit",boss.entity_id).size() == 1, "持续18帧攻击窗口不重复扣血")
	await _step(1)
	_check(not boss.attack_instance.active and boss.animation.get_current_action() == &"idle", "动画和战斗恢复由GAS/Core管理；动作%s，状态%d，释放%s" % [boss.animation.get_current_action(),boss.action_state.current,boss.attack_instance.active])
	await _fresh()
	_move(player,750)
	boss.animation.set_facing(-1)
	boss.try_activate_skill(&"jushi_lingjun_skill1")
	await _step(0.51)
	_check(not _events("battle.attack.hit",boss.entity_id).is_empty(), "左右镜像后的原判定能命中")

func _verify_notes() -> void:
	await _fresh()
	_move(player,1370)
	controller.enabled = true
	await _step(0.01)
	_check(boss.attack_instance != null and boss.attack_instance.ability_id == &"jushi_lingjun_skill2", "专属AI优先使用5秒琵琶技能")
	var announced := _events("battle.boss.announced",boss.entity_id)
	var started := _events("battle.boss.action_started",boss.entity_id)
	_check(announced.size() == 1 and started.size() == 1 and announced[0].sequence < started[0].sequence and announced[0].combat_time == started[0].combat_time, "原版播报先通知，与动作同战斗时刻开始")
	controller.enabled = false
	await _step(0.77)
	_check(_active_objects().is_empty(), "真实音符不早于第24帧")
	await _step(0.02)
	var notes := _active_objects("projectile")
	_check(notes.size() == 5 and _events("battle.boss.objects_spawned")[0].source_frame == 24, "第24帧同时生成5枚原扇形音符")
	if notes.size() == 5:
		_check(notes[0].velocity.x > 0 and notes[0].velocity.y < 0 and notes[4].velocity.y > 0, "650源速度与20度间隔正确")
	var hp := player.attributes.get_vital_value(&"health")
	await _step(0.3)
	_check(player.attributes.get_vital_value(&"health") < hp, "独立弹道使用GAS实际扣血和共享跳字")
	await _step(0.5)
	_check(_active_objects("projectile").is_empty(), "linkParentState音符在动作结束清理")
	_check(feedback.banner.visible, "2秒播报可自然长于44帧动作，不由动作结束截断")
	await _step(1)
	_check(not feedback.banner.visible, "原版7帧入场、2秒后离场、8帧销毁时序")
	await _fresh()
	_move(player,430)
	boss.animation.set_facing(-1)
	boss.try_activate_skill(&"jushi_lingjun_skill2")
	await _step(0.8)
	notes = _active_objects("projectile")
	_check(notes.size() == 5 and notes[2].velocity.x == -1300 and is_equal_approx(notes[2].global_position.x,700), "向左发射位置和速度镜像")

func _verify_low_fps() -> void:
	await _fresh()
	_move(player,1370)
	boss.try_activate_skill(&"jushi_lingjun_skill2")
	var hp := player.attributes.get_vital_value(&"health")
	await _step(2)
	_check(_events("battle.boss.objects_spawned").size() == 1 and player.attributes.get_vital_value(&"health") < hp and _active_objects().is_empty(), "大delta跨越产生、飞行、结束时仍结算音符，没有先清理后漏命中")
	_check(_events("battle.attack.hit",boss.entity_id).size() <= 5, "低帧率每弹每目标仍最多命中一次")
#endregion
#region 石墙成形、实体碰撞、五秒存活与取消
func _verify_wall() -> void:
	await _fresh()
	_move(player,1150)
	boss.try_activate_skill(&"jushi_lingjun_skill3")
	await _step(18.0/30)
	_check(_active_objects().is_empty(), "石墙未到第19帧不生成")
	await _step(1.1/30)
	var walls := _active_objects("wall")
	_check(walls.size() == 1 and walls[0].collision.disabled, "第19帧先播放12帧成形动画")
	await _step(0.4)
	walls = _active_objects("wall")
	_check(walls.size() == 1 and not walls[0].collision.disabled and walls[0].player.current_animation == &"skill3_2", "成形后切原循环动画并启用实体碰撞")
	if walls.size() == 1:
		_check(is_equal_approx(walls[0].global_position.x,1350), "原版225源像素生成位置")
		player.move_axis = 1
		player.running = true
		await _step(0.5)
		_check(player.global_position.x < 1300, "人物扫掠移动不能穿过实体石墙")
		player.move_axis = 0
	_check(not boss.attack_instance.active and not _active_objects("wall").is_empty(), "不跟随父状态的石墙独立于技能后摇存活")
	var before := walls[0].age if not walls.is_empty() else 0.0
	session.set_paused(true)
	await _step(10)
	_check(walls.is_empty() or walls[0].age == before, "暂停冻结石墙寿命和动画")
	session.set_paused(false)
	await _step(5)
	_check(_active_objects().is_empty() and (walls.is_empty() or walls[0].collision.disabled), "成形后五秒结束清理碰撞")
	await _fresh()
	boss.try_activate_skill(&"jushi_lingjun_skill3")
	await _step(0.7)
	boss.cancel_skill(&"test_cancel")
	await _step(2)
	_check(_active_objects().is_empty() and _events("battle.boss.objects_spawned").size() == 1, "取消已生成石墙及待执行事件，无特效/碰撞残留")
#endregion
#region 可配置前置播报、控制与一次性血量阶段
func _verify_wall_no_contact_damage() -> void:
	for direction in [1, -1]:
		await _fresh()
		boss.animation.set_facing(direction)
		player.super_armor = false
		player.attributes.set_base_value(&"hpMax", 275)
		player.attributes.set_base_value(&"reHP", 0)
		player.attributes.get_vital(&"health").set_current_value(275)
		player.global_position = boss.global_position + Vector2(450 * direction, 0)
		_check(boss.try_activate_skill(&"jushi_lingjun_skill3"), "生成原版无接触伤害石墙")
		await _step(0.7)
		var wall := _active_objects("wall")[0]
		_check(wall.definition.maximum_hits == 0 and wall.definition.hit_interval == 0 and wall.definition.is_valid(), "原atkMax/atkInterval=0为无命中，不解释成无限伤害")
		await _step(0.25)
		_check(player.attributes.get_vital_value(&"health") == 275 and wall.hits.is_empty(), "成形动画与人物重叠也不扣血或积累命中")
		await _step(0.25)
		_check(not wall.collision.disabled and player.is_alive() and player.attributes.get_vital_value(&"health") == 275, "实体墙形成后重叠不产生硬直连击")
		player.global_position = Vector2(wall.global_position.x - 160 * direction, 1056)
		player.move_axis = direction
		player.running = true
		await _step(1.0)
		_check(player.motion.on_wall and player.is_alive() and player.attributes.get_vital_value(&"health") == 275, "左右持续靠墙仍保持实体阻挡且无接触伤害")
		_check(_events("battle.attack.hit", boss.entity_id).filter(func(row): return row.get("object_id") == &"jade_wall").is_empty(), "低帧率多子步不发布墙壁伤害/被动触发事件")
		player.move_axis = 0
		await _step(5)
		_check(not wall.active and wall.collision.disabled and player.attributes.get_vital_value(&"health") == 275, "墙壁按原寿命回收，整个生命周期不损失生命")

func _verify_lead_control() -> void:
	await _fresh()
	var rule := controller.boss_profile.skills[1]
	rule.announcement_lead_seconds = 0.6
	rule.warning_rect = Rect2(0,-100,400,100)
	controller.enabled = true
	await _step(0.01)
	_check(controller.pending_rule != null and feedback.warning.visible and boss.attack_instance == null, "扩展Boss可先播报预警，此时没有技能实例")
	var announcement := _events("battle.boss.announced",boss.entity_id)[0]
	_check(feedback.warning.polygon[1] == announcement.origin+Vector2(400*int(announcement.facing),-100), "预警世界坐标只换算一次")
	session.set_paused(true)
	var age := feedback.banner_age
	await _step(5)
	_check(feedback.banner_age == age and is_equal_approx(controller.lead_remaining,0.6) and boss.attack_instance == null and (not feedback.music.playing or feedback.music.stream_paused), "暂停不消耗播报或预警，并暂停正在播放的声音")
	session.set_paused(false)
	await _step(0.59)
	_check(boss.attack_instance == null, "前置时间未到不能攻击")
	await _step(0.01)
	_check(boss.attack_instance != null and boss.attack_instance.active, "前置时间结束才通过Core/GAS开始动作")
	await _fresh()
	controller.boss_profile.skills[1].announcement_lead_seconds = 0.6
	controller.enabled = true
	await _step(0.01)
	boss.apply_status_definition(&"stun",player)
	await _step(1)
	_check(controller.pending_rule == null and not feedback.banner.visible and _events("battle.boss.action_started").is_empty(), "受控取消前置播报，恢复后不会补发旧攻击")

func _verify_phases() -> void:
	await _fresh()
	var phase := BattleBossPhase.new()
	phase.phase_id = &"threshold_70"
	phase.health_ratio = 0.7
	phase.entry_ability_id = &"jushi_lingjun_skill1"
	phase.invulnerable_during_entry = true
	phase.required_conditions = [&"阶段许可"]
	var level := session.catalog.instantiate_definition("levels", &"碧玉径") as BattleLevelDefinition
	level.condition_ids.append(&"阶段许可")
	_check(scene.flow.start(level), "阶段验收使用真实关卡条件入口")
	var second := BattleBossPhase.new()
	second.phase_id = &"threshold_30"
	second.health_ratio = 0.3
	controller.boss_profile.phases = [phase,second]
	controller.enabled = true
	controller.boss_profile.intro_seconds = 100
	boss.try_activate_skill(&"jushi_lingjun_skill2")
	boss.attributes.get_vital(&"health").set_current_value(500)
	boss.attributes.get_vital(&"health").set_current_value(1000)
	_check(controller.threshold_reached.has(phase.phase_id) and controller.phase_transitions == 0, "攻击过程中达到阈值先锁存，回血不丢失等待阶段")
	await _step(2)
	controller.boss_profile.intro_seconds = 0
	await _step(0.01)
	_check(controller.phase_transitions == 0, "达到血量阈值但前置机关未完成时不转换")
	_check(scene.flow.set_condition(&"阶段许可"), "统一关卡入口完成阶段前置条件")
	await _step(0.01)
	_check(controller.phase_transitions == 1 and controller.phase_id == phase.phase_id and boss.damage_rules.has_flag(&"immune"), "动作结束后开始一次阶段进入动作并采用统一无敌规则")
	var result := session.apply_secondary_damage(boss,player,10,&"test")
	_check(result.is_immune and result.actual_hp_loss == 0, "阶段保护仍走GAS生命入口")
	await _step(2)
	_check(not boss.damage_rules.has_flag(&"immune") and _events("battle.boss.phase_finished").size() == 1, "阶段动作结束移除临时规则且只通知一次")
	boss.attributes.get_vital(&"health").set_current_value(600)
	await _step(0.1)
	_check(controller.phase_transitions == 1, "反复跨越同一阈值不会重复阶段")
	boss.cancel_skill()
	boss.attributes.get_vital(&"health").set_current_value(250)
	await _step(0.01)
	_check(controller.phase_transitions == 2 and controller.phase_id == second.phase_id, "多个下降阈值按配置顺序独立执行")
#endregion
#region 召唤计数、保护动作与取消清理
func _verify_summons() -> void:
	await _fresh()
	controller.boss_profile.maximum_summons = 2
	_check(controller.summon_monsters([&"剑舞",&"驭兽使",&"剑舞"],Vector2(-100,0)) == 2 and controller.summons.size() == 2 and controller.summon_total == 2, "通用召唤入口实际生成独立怪物并限制存活数量")
	var ids := controller.summons.keys()
	var minion := session.get_entity(ids[0]) as BattleEntity2D
	var other := session.get_entity(ids[1]) as BattleEntity2D
	_check(minion.faction_id == boss.faction_id and minion.attributes != other.attributes and minion.abilities != other.abilities, "召唤复用原组件、阵营、独立技能及属性")
	_check(minion.is_spawning() and other.is_spawning(), "召唤沿用原showAppear出场，随后才行动")
	minion._finish_spawn_appearance()
	session.apply_secondary_damage(minion,player,100000,&"test")
	session.publish_event(&"battle.entity.killed",player,minion)
	_check(controller.summon_deaths == 1 and controller.summons.size() == 1, "重复Vital与Core死亡不会重复召唤计数")
	session.despawn_entity(other.entity_id)
	await _step()
	_check(controller.summons.is_empty() and controller.summon_deaths == 1, "存活回收扣除存活数，不算死亡")
	controller.summon_monsters([&"剑舞"])
	session.apply_secondary_damage(boss,player,100000,&"test")
	_check(controller.summons.is_empty() and _active_objects().is_empty(), "Boss死亡立即回收召唤和技能对象")
	await _step(30)
	_check(controller.summon_total == 3 and controller.successful_casts == 0, "死亡后不会继续选择技能或生成召唤")
	await _fresh()
	var marker := BattleFrameEvent.new()
	marker.source_frame = 6
	marker.event_id = &"battle.boss.summon"
	marker.payload = {"monster_ids": [&"剑舞"], "spawn_offset": Vector2(-100,0)}
	var timeline := BattleFrameTimelineFeature.new()
	timeline.duration_frames = 12
	timeline.animation_action = &"attack_3"
	timeline.commit_resources = true
	timeline.events = [marker]
	var ability := GameplayAbilityDefinition.new()
	ability.ability_id = &"boss_test_summon"
	ability.features = [timeline]
	boss.abilities.learn_ability(ability)
	_check(boss.try_activate_skill(ability.ability_id), "召唤也通过真实GAS技能时间轴开始")
	await _step(5.0/30)
	_check(controller.summon_total == 0, "召唤事件不早于配置素材帧")
	await _step(1.01/30)
	_check(controller.summon_total == 1 and _events("battle.boss.summoned").size() == 1, "第6帧Core事件实际创建召唤怪")
	boss.cancel_skill()
	boss.try_activate_skill(ability.ability_id)
	boss.cancel_skill()
	await _step(1)
	_check(controller.summon_total == 1, "取消技能清理未执行的召唤事件")

func _verify_protection_and_cleanup() -> void:
	await _fresh()
	boss.try_activate_skill(&"jushi_lingjun_skill2")
	await _step(0.8)
	var info := DamageInfo.new(player)
	info.final_damage = 1
	info.normal_damage = 1
	boss.receive_damage_info(info,&"normal",60,{"protection_parameters":{"protectPoint":25000,"protectPointB":0},"original_skill_id":1101010})
	_check(boss.protection.trigger_count == 1 and boss.protection.active and boss.action_state.current == BattleActionState2D.State.PROTECT and _active_objects().is_empty(), "原25000满值进入Core保护，取消弹道与攻击")
	var result := session.apply_secondary_damage(boss,player,10,&"test")
	_check(result.is_immune, "保护规则阻止伤害，与普通技能霸体区分")
	await _step(0.81)
	_check(boss.protection.active and TagManager.has_tag(boss, &"state.invulnerable"), "原通用保护Buff持续两秒，不提前结束")
	await _step(0.2)
	_check(not boss.protection.active and boss.action_state.current != BattleActionState2D.State.PROTECT, "保护结束恢复动作规则")
	_check(TagManager.has_tag(boss, &"state.invulnerable"), "动作一秒结束但原无敌Buff持续两秒")
	await _step(1)
	boss.protection.register_hit({"original_skill_id":1101010,"protection_parameters":{"protectPoint":1000}},1,1167)
	await _step(0.3)
	_check(feedback.protect.value > 0 and feedback.protect_label.text.contains("25000"), "即使HP未变，公共保护条仍跟随保护分数更新")
	var other := session.spawn_entity_2d("monsters",&"巨石灵君",Vector2(1800,1056))
	other.ai_controller.enabled = false
	_check(other.protection.score == 0 and other.ai_controller.successful_casts == 0 and other.ai_controller.summons.is_empty(), "两个Boss保护、决策与召唤运行状态独立")
	session.clear_battle()
	await _step(10)
	_check(session.get_entities().is_empty() and not feedback.bar.visible and not feedback.banner.visible, "卸载清理所有实体、Boss订阅与公共表现")
#endregion
#region 原始悟空属性、真实攻击打通五区域与Boss
func _verify_playable_level() -> void:
	await _fresh(false)
	var baseline := player.attributes.get_snapshot()
	_check(baseline.hp == 275 and baseline.atk == 26 and baseline.level == 1 and not player.super_armor, "可玩验收使用实际初始悟空，无额外生命或霸体")
	var won := false
	var damage_to_boss := 0.0
	for frame in range(10000):
		if not player.is_alive() or scene.flow.state == BattleLevelInstance2D.State.FAILED: break
		var target: BattleEntity2D
		var distance := INF
		for actor in session.get_entities():
			if actor == player or not actor.is_alive() or not actor is BattleEntity2D: continue
			var gap := absf(actor.global_position.x-player.global_position.x)
			if gap < distance:
				target = actor
				distance = gap
		var region: BattleRegionInstance = scene.flow.regions[scene.flow.current_region_index]
		var goal := region.definition.exit_rect.get_center().x if region.exit_open else (target.global_position.x if target != null else region.definition.entry_rect.get_center().x)
		var axis := signf(goal-player.global_position.x) if absf(goal-player.global_position.x) > (110 if target != null and not region.exit_open else 10) else 0.0
		var protecting := target != null and target.ai_controller is BattleBossController2D and TagManager.has_tag(target, &"state.invulnerable")
		# 按真实保护规则走位等待无敌结束，不对无敌Boss持续贴身空打。
		if protecting: axis = signf(player.global_position.x - target.global_position.x) if distance < 450 else 0.0
		var move := CoreOperationIntent.new()
		move.action = &"move_left" if axis < 0 else &"move_right"
		move.origin = &"test_player"
		move.phase = CoreOperationIntent.Phase.CHANGED
		move.payload = {"move_axis":axis,"running":true}
		player.action_state.handle_operation(move)
		if target != null and not region.exit_open and distance < 230 and not protecting:
			if player.action_state.get_permission(&"turn",player.action_profile): player.animation.set_facing(1 if target.global_position.x > player.global_position.x else -1)
			if frame%6 == 0:
				var attack := CoreOperationIntent.new()
				attack.action = &"attack"
				attack.origin = &"test_player"
				player.action_state.handle_operation(attack)
		if player.motion.on_wall and player.motion.grounded and frame%30 == 0: player.try_jump()
		await _step()
		if region.exit_open and scene.flow.current_region_index == 4: scene.flow.request_exit(player)
		if scene.flow.state == BattleLevelInstance2D.State.WON:
			won = true
			break
	for row in _events("battle.attack.hit",player.entity_id):
		if row.get("entity") is BattleEntity2D and is_instance_valid(row.entity) and row.entity.definition_id == &"巨石灵君": damage_to_boss += row.actual_hp_loss
	_check(won and scene.flow.death_count == 34 and damage_to_boss >= 1167, "原悟空属性、真实Core普攻与GAS伤害完成32小怪/容器/Boss/出口：状态%d区域%d死亡%d生命%d Boss伤害%d" % [scene.flow.state,scene.flow.current_region_index+1,scene.flow.death_count,player.attributes.get_vital_value(&"health"),damage_to_boss])
	if won: print("PASS playable first level: original level1 Wukong, hp275/atk26, actual combo only; 34 targets, Boss damage %d, remaining HP %d" % [damage_to_boss,player.attributes.get_vital_value(&"health")])
#endregion
