extends Node
#region 真实第一关、固定时钟与事件
var demo: Node2D
var session: BattleSession
var player: BattleEntity2D
var sword: BattleEntity2D
var beast: BattleEntity2D
var peer: BattleEntity2D
var checks: int = 0
var failures: Array[String] = []
var hits: Array[Dictionary] = []

class CustomPolicy extends BattleAIPolicy2D:
	func decide(_controller: BattleAIController2D) -> Dictionary:
		return {"state": &"CUSTOM", "axis": 0.5}

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _ready() -> void:
	CoreSystem.event_bus.event_pushed.connect(_event)
	await _fresh()
	_verify_resources()
	await _verify_jump_height()
	await _verify_original_motion()
	await _fresh()
	await _verify_combat()
	await _verify_windows()
	await _verify_control()
	await _verify_policies()
	CoreSystem.event_bus.event_pushed.disconnect(_event)
	demo.free()
	await get_tree().process_frame
	if failures.is_empty():
		print("PASS stage 11 monster AI: %d checks; Dungeon1/32 authored monsters/original atlas/AB frames, autonomous melee/ranged, GAS cooldown isolation, control/death, clocks, return/patrol/jump/flee/target policies" % checks)
		get_tree().quit()
	else:
		for failure in failures: push_error(failure)
		get_tree().quit(1)

func _event(id: String, payload: Array) -> void:
	if id == "battle.attack.hit" and payload.size() == 1 and is_instance_valid(session) and payload[0].get("battle_id") == session.battle_id:
		hits.append(payload[0].duplicate())

func _paths(root: Node) -> Array[String]:
	var result: Array[String] = []
	for child in root.get_children():
		result.append(String(root.get_path_to(child)))
		for descendant in _paths(child): result.append("%s/%s" % [child.name, descendant])
	return result

func _fresh() -> void:
	if is_instance_valid(demo): demo.free()
	demo = load("res://tests/fixtures/first_level_demo.tscn").instantiate()
	demo.enable_player_controls = false
	var before := _paths(demo)
	add_child(demo)
	_check(_paths(demo) == before, "启动复用全部预置角色/AI/GAS/地形/表现节点")
	session = demo.session
	session.set_physics_process(false)
	player = demo.player
	sword = demo.get_node("BattleSession/Actors/Sword01")
	beast = demo.get_node("BattleSession/Actors/Beast01")
	peer = demo.get_node("BattleSession/Actors/Sword02")
	for actor in demo.monsters:
		actor.ai_controller.enabled = false
		actor.ai_controller.profile = actor.ai_controller.profile.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
	player.attributes.set_base_value(&"hpMax", 100000)
	(player.attributes.get_vital(&"health") as HealthVital).set_current_value(100000)
	player.super_armor = true
	await _step(30)
	hits.clear()

func _step(ticks: int, delta: float = 1.0 / 60.0) -> void:
	for tick in range(ticks):
		await get_tree().physics_frame
		session.advance_physics(delta)

func _place(actor: BattleEntity2D, x: float) -> void:
	actor.global_position = Vector2(x,650)
	actor.velocity = Vector2.ZERO
	actor.motion.clear_impulse()
	actor.ai_controller.home = actor.global_position
	actor.ai_controller.decision_remaining = 0.0

func _hits(source: BattleEntity2D) -> int:
	var count := 0
	for row in hits:
		if row.source_entity_id == source.entity_id and row.target_entity_id == player.entity_id: count += 1
	return count
#endregion
#region 原版身份与场景组件
func _verify_resources() -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/monsters/original_first_level.json"))
	_check(original.dungeon.name == "碧玉径" and original.dungeon.monsterNum == "16;16;1;1;1;6", "原版Dungeon1身份/普通怪数量")
	_check(demo.monsters.size() == 32 and session.get_entities().size() == 33 and session.current_level_id == &"碧玉径", "32个小怪和悟空统一注册关卡")
	for actor in demo.monsters:
		_check(actor.ai_controller == actor.get_node("AIController") and actor.action_state.machine is BattleActionStateMachine2D, "预置AI复用Core动作规则")
		_check(actor.attributes.get_value(&"hpMax") == 199 and actor.attributes.get_value(&"atk") == 9 and actor.attributes.get_value(&"phyDef") == 2 and actor.attributes.current_level == 2, "原版小怪生命199攻击9防御2等级2")
		_check(actor.animation.get_action_duration(&"death") > 1.0 and actor.animation.get_action_duration(&"attack_1") > 1.0, "原版序列帧可用AnimationPlayer编辑")
	_check(sword.ai_controller.profile.original_ai_id == 10011 and beast.ai_controller.profile.original_ai_id == 10012, "近战/远程分别使用原版AI配置")
	_check(sword.abilities.get_ability_instance(&"jianwu_skill1") != peer.abilities.get_ability_instance(&"jianwu_skill1"), "技能实例独立")
	_check((session.damage_strategy as BattleOriginalDamageStrategy).get_skill_parameters(&"yushoushi_skill1").source_skill_id == 2000100, "原版伤害技能映射")
	var saved := sword.ai_controller.profile
	sword.ai_controller.profile = null
	_check(not sword.get_component_configuration_error().is_empty(), "无AI配置在场景装配时明确报错")
	sword.ai_controller.profile = saved
	var radius := saved.leash_radius
	saved.leash_radius = INF
	_check(not saved.is_valid(), "AI活动边界拒绝非有限值")
	saved.leash_radius = radius
#endregion
#region 怪物起跳高度、落地与低帧率
func _verify_jump_height() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle2d/original_reactions/source.json"))
	var gravity := float(source.nape_gravity) * pow(float(source.source_fps) * float(source.nape_delta), 2) * float(source.display_scale)
	for slug in ["jianwu", "yushoushi", "jushi_lingjun", "revival_vessel"]:
		var profile := load("res://data/monsters/%s/actions.tres" % slug) as BattleActionProfile2D
		_check(is_equal_approx(profile.gravity, gravity), "四类怪物统一原版世界重力:" + slug)
		_check(profile.maximum_jumps == (0 if slug == "revival_vessel" else 1), "固定容器禁止主动跳跃，战斗怪物仅一跳:" + slug)
	for actor: BattleEntity2D in [sword, beast]:
		for delta in [1.0 / 60.0, 1.0 / 30.0, 0.2]:
			_place(actor, 4000)
			actor.move_axis = 0.0
			actor.action_state.enter(BattleActionState2D.State.IDLE)
			await _step(1)
			var start_y := actor.global_position.y
			_check(actor.try_jump(), "怪物通过动作入口起跳")
			_check(is_equal_approx(actor.velocity.y, actor.action_profile.jump_velocity), "起跳使用该类怪物配置")
			_check(not actor.try_jump(), "同帧不能重复起跳")
			var top_y := start_y
			var elapsed := 0.0
			var rejected_air_jump := false
			while elapsed < 0.8:
				await _step(1, delta)
				elapsed += delta
				top_y = minf(top_y, actor.global_position.y)
				if elapsed >= 0.1 and not actor.motion.grounded:
					rejected_air_jump = not actor.try_jump()
			var expected_height := pow(actor.action_profile.jump_velocity, 2) / (2 * gravity)
			_check(start_y - top_y > expected_height - 20 and start_y - top_y < expected_height, "怪物实际跳高符合重力及低帧率子步积分")
			_check(rejected_air_jump, "怪物空中不会重复跳跃")
			_check(actor.motion.grounded and actor.motion.jumps_used == 0 and absf(actor.global_position.y - start_y) < 0.1, "怪物正常落地并重置跳跃预算")
#endregion
#region 原版速度与逐段横向击退实测
func _verify_original_motion() -> void:
	_check(player.attributes.get_value(&"walkSpeed") == 420 and player.attributes.get_value(&"runSpeed") == 600, "悟空与怪物统一2倍世界速度单位")
	for running in [false, true]:
		for direction in [1, -1]:
			player.global_position = Vector2(4000, 650)
			player.move_axis = direction
			player.running = running
			player.action_state.enter(BattleActionState2D.State.IDLE)
			await _step(30)
			var original_speed := 300.0 if running else 210.0
			_check(absf(player.global_position.x - 4000 - direction * original_speed) < 0.1, "左右行走/跑步半秒世界距离与原版换算一致")
	player.move_axis = 0
	player.running = false
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle2d/original_reactions/source.json"))
	for row: Dictionary in source.steps:
		var ability := session.catalog.instantiate_definition("skills", StringName("sunwukong_" + row.action)) as GameplayAbilityDefinition
		var timeline := ability.features[-1] as BattleFrameTimelineFeature
		var payloads: Array[Dictionary] = []
		for event in timeline.events: payloads.append(event.payload)
		for segment in timeline.attack_segments: payloads.append(segment.get_payload())
		for index in range(payloads.size()):
			var raw: Dictionary = row.impacts[index]
			var movement: PackedStringArray = String(raw.get("targetMove", "") if not String(raw.get("targetMove", "")).is_empty() else row.skill_target_move).split(";")
			var stiff := float(raw.stiff)
			var context: Dictionary = payloads[index].duplicate(true)
			_check(is_equal_approx(context.knockback_speed, float(movement[0]) * 2) and is_equal_approx(context.knockback_duration, stiff), "第一关使用原版单段速度/时长而非阶段9验收配置:" + row.action + str(index))
			for direction in [1, -1]:
				for delta in [1.0 / 60.0, 1.0 / 30.0, 0.2]:
					_place(sword, 4500)
					sword.protection.clear()
					sword.action_state.enter(BattleActionState2D.State.IDLE)
					context.attack_facing = direction
					sword.receive_damage(1, player, &"normal", 60, context)
					var elapsed := 0.0
					while elapsed < stiff + 0.1:
						sword.motion.advance(delta, 0, sword.action_profile)
						elapsed += delta
					var distance: float = direction * float(movement[0]) * 2 * stiff
					_check(absf(sword.global_position.x - 4500 - distance) < 0.1, "真实怪物受击位移=原版速度×时长×比例，左右及低帧率一致:" + row.action + str(index))
					var stop_x := sword.global_position.x
					sword.motion.advance(0.2, 0, sword.action_profile)
					_check(absf(sword.global_position.x - stop_x) < 0.01, "横向击退到期不残留速度")
#endregion
#region 自主攻击及原AB帧几何
func _verify_combat() -> void:
	_place(sword,1100)
	player.global_position = Vector2(650,650)
	sword.ai_controller.enabled = true
	await _step(210)
	_check(sword.ai_controller.successful_casts == 1 and _hits(sword) == 2, "剑舞自主追击，两个窗口各命中一次")
	_check(player.attributes.get_vital_value(&"health") < 100000 and sword.global_position.x < 1100, "近战真实移动与扣血")
	var instance := sword.abilities.get_ability_instance(&"jianwu_skill1")
	_check((instance.get_feature("CooldownFeature") as CooldownFeature).get_cooldown_remaining(instance) > 0.0, "当前怪物等待5秒GAS冷却")
	var other := peer.abilities.get_ability_instance(&"jianwu_skill1")
	_check((other.get_feature("CooldownFeature") as CooldownFeature).get_cooldown_remaining(other) == 0.0, "另一只同类怪的冷却仍为0")
	sword.ai_controller.enabled = false
	_place(beast,1050)
	player.global_position = Vector2(700,650)
	beast.ai_controller.enabled = true
	await _step(110)
	var left_hit := false
	for row in hits:
		if row.source_entity_id == beast.entity_id and row.get("attack_facing", 0) == -1: left_hit = true
	_check(beast.ai_controller.successful_casts == 1 and _hits(beast) == 1 and left_hit, "远程自主出手，命中时向左镜像且只命中一次")
	await _step(50)
	_check(beast.global_position.x > 1050, "远程攻击后退步")
	_check(beast.animation.get_slot_attachment_name(&"Effect1").is_empty(), "攻击后无兽形特效残留")

func _verify_windows() -> void:
	await _fresh()
	_place(beast,1050)
	player.global_position = Vector2(700,650)
	beast.animation.set_facing(-1)
	_check(beast.request_attack(), "远程通过普通攻击入口请求")
	await _step(1,1.28)
	_check(_hits(beast) == 1, "低帧率跨越命中帧不遗漏")
	var segment: BattleAttackSegment = (beast.abilities.get_ability_instance(&"yushoushi_skill1").get_feature("BattleFrameTimelineFeature") as BattleFrameTimelineFeature).attack_segments[0]
	_check(segment.start_frame == 36 and segment.end_frame == 40 and segment.hit_rect_frames.size() == 4, "原版AB36～39帧")
	_check(segment.get_payload_at_frame(36).hit_rect != segment.get_payload_at_frame(39).hit_rect, "同段逐帧变化几何")
	await _step(10)
	_check(_hits(beast) == 1, "换框和重叠仍共享段/目标去重")
	beast.cancel_skill()
	await _step(5)
	_check(not beast.attack_instance.active and not beast.attack_hitbox.visible and beast.animation.get_slot_attachment_name(&"Effect1").is_empty(), "取消清除窗口和特效")
#endregion
#region 受控、暂停慢动作、死亡与实例隔离
func _verify_control() -> void:
	await _fresh()
	_place(sword,800)
	player.global_position = Vector2(650,650)
	sword.ai_controller.enabled = true
	sword.apply_status_definition(&"stun",player)
	await _step(60)
	_check(sword.ai_controller.successful_casts == 0 and absf(sword.global_position.x-800) < 0.001 and sword.ai_controller.state == &"CONTROLLED", "眩晕阻止AI移动和施放")
	await _step(70)
	_check(sword.ai_controller.successful_casts == 1, "控制结束恢复攻击")
	var instance := sword.abilities.get_ability_instance(&"jianwu_skill1")
	var cd := instance.get_feature("CooldownFeature") as CooldownFeature
	var remaining := cd.get_cooldown_remaining(instance)
	var position_before := sword.global_position
	session.set_paused(true)
	await _step(30)
	_check(cd.get_cooldown_remaining(instance) == remaining and sword.global_position == position_before, "暂停冻结AI/移动/冷却")
	session.set_paused(false)
	session.set_time_scale(0.5)
	await _step(30)
	_check(absf(remaining-cd.get_cooldown_remaining(instance)-0.25) < 0.02, "慢动作统一影响冷却")
	session.set_time_scale(1.0)
	sword.attributes.set_base_value(&"atk",99)
	_check(peer.attributes.get_value(&"atk") == 9, "同类怪属性独立")
	sword.receive_damage(10000,player)
	var count := sword.ai_controller.successful_casts
	await _step(360)
	_check(not sword.is_alive() and sword.ai_controller.state == &"DEAD" and sword.ai_controller.successful_casts == count and not sword.attack_instance.active and sword.move_axis == 0.0, "死亡停止攻击与移动并清理技能")
	await _fresh()
	_place(beast,1050)
	player.global_position = Vector2(700,650)
	beast.ai_controller.enabled = true
	await _step(20)
	beast.apply_status_definition(&"stun",player)
	await _step(80)
	_check(_hits(beast) == 0 and not beast.attack_instance.active and beast.animation.get_slot_attachment_name(&"Effect1").is_empty(), "眩晕打断远程前摇不发出旧命中")
#endregion
#region 返回巡逻、跳跃、逃离与目标评分扩展
func _verify_policies() -> void:
	await _fresh()
	var ai := sword.ai_controller
	_place(sword,1300)
	ai.enabled = true
	player.global_position = Vector2(900,650)
	await _step(30)
	_check(ai.target == player, "阵营索敌")
	player.global_position.x = 5000
	var saw_return := false
	var nearest_home: float = INF
	for tick in range(60):
		await _step(1)
		saw_return = saw_return or ai.state == &"RETURN"
		nearest_home = minf(nearest_home, absf(sword.global_position.x-ai.home.x))
	_check(saw_return and nearest_home <= ai.profile.home_tolerance and ai.target == null, "丢失目标先返回出生点，再恢复巡逻")
	var start := sword.global_position.x
	await _step(60)
	_check(absf(sword.global_position.x-start) > 50.0 and ai.target == null, "空闲巡逻")
	_place(sword,2900)
	player.global_position = Vector2(3200,650)
	ai.decision_remaining = 0.0
	var serial := sword.motion.jump_serial
	await _step(80)
	_check(sword.motion.jump_serial > serial and sword.global_position.x > 3000, "提交跳跃意图跨过矮墙")
	sword.cancel_skill()
	_place(sword,2000)
	player.global_position = Vector2(1800,650)
	ai.profile.flee_health_ratio = 0.5
	(sword.attributes.get_vital(&"health") as HealthVital).set_current_value(50)
	ai.decision_remaining = 0.0
	await _step(12)
	_check(ai.state == &"FLEE" and sword.global_position.x > 2000, "低生命逃离")
	var alternate := session.spawn_entity_2d("characters",&"孙悟空",Vector2(2300,650))
	alternate.operations.enabled = false
	alternate.attributes.set_base_value(&"atk",500)
	(alternate.attributes.get_vital(&"health") as HealthVital).set_current_value(10)
	ai.profile.target_selector.mode = "highest_attack"
	_check(ai.profile.target_selector.select_target(sword,ai.profile,ai.home) == alternate, "优先最高攻击目标")
	ai.profile.target_selector.mode = "lowest_health"
	_check(ai.profile.target_selector.select_target(sword,ai.profile,ai.home) == alternate, "优先最低生命目标")
	session.despawn_entity(alternate.entity_id)
	await _step(1)
	_check(ai.profile.target_selector.select_target(sword,ai.profile,ai.home) == player, "目标离场后重新索敌")
	ai.profile.leash_radius = 500.0
	sword.global_position.x = ai.home.x + 600.0
	ai.decision_remaining = 0.0
	await _step(1)
	_check(ai.returning and ai.state == &"RETURN" and sword.move_axis < 0.0, "越界后朝出生点返回")
	ai.profile.policy = CustomPolicy.new()
	ai.profile.flee_health_ratio = 0.0
	ai.returning = false
	_place(sword,2000)
	await _step(12)
	_check(ai.state == &"CUSTOM" and sword.global_position.x > 2000 and sword.move_axis == 0.5, "自定义Policy资源通过同一Core意图执行")
	sword.apply_status_definition(&"slow",player)
	var slow_start := sword.global_position.x
	await _step(12)
	_check(sword.attributes.get_value(&"walkSpeed") == 100 and absf(sword.global_position.x-slow_start-10) < 1.0, "AI移动即时使用GAS减速后的最终速度")
#endregion
