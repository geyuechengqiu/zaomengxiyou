extends Node
## 真实 GAS / Core / HealthVital / 2D 扫掠碰撞，不用目测替代验收。

#region 夹具、固定战斗时钟与入口
const State = BattleActionState2D.State
var demo: Node2D
var session: BattleSession
var player: BattleEntity2D
var target: BattleEntity2D
var other: BattleEntity2D
var checks: int = 0
var failures: Array[String] = []
var hits: Array[Dictionary] = []
var reaction_events: Array[Dictionary] = []

func _ready() -> void:
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	await _verify_protection_formula()
	await _verify_reaction_and_policies()
	await _verify_physics_and_lifecycle()
	await _verify_native_attacks_and_clock()
	if DisplayServer.get_name() != "headless" and "--capture-stage9" in OS.get_cmdline_user_args():
		await _capture_previews()
	CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	if is_instance_valid(demo):
		demo.free()
	if failures.is_empty():
		print("PASS stage 9: %d checks; original per-Boss protection, per-target/skill counts/reset, independent HP/reaction/policies, swept knockback/platforms, launch/down/getup/death, native five-combo and hit-stop" % checks)
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error(failure)
		get_tree().quit(1)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _fresh() -> void:
	if is_instance_valid(demo):
		demo.free()
	demo = load("res://examples/hit_reaction_demo.tscn").instantiate()
	demo.enable_player_controls = false
	var authored_nodes := _paths(demo)
	add_child(demo)
	_check(_paths(demo) == authored_nodes, "角色、保护条、动画与满值UI全部预置，启动不生成节点")
	session = demo.session
	session.set_physics_process(false)
	player = demo.player
	target = demo.dummies[1]
	other = demo.dummies[0]
	await _step(10)
	hits.clear()
	reaction_events.clear()

func _paths(node: Node) -> Array[String]:
	var result: Array[String] = []
	for child in node.get_children():
		result.append(str(child.name))
		for path in _paths(child):
			result.append(str(child.name) + "/" + path)
	return result

func _step(count: int = 1, delta: float = 1.0 / 60.0) -> void:
	for tick in range(count):
		await get_tree().physics_frame
		session.advance_physics(delta)

func _on_event(id: String, payload: Array) -> void:
	if not is_instance_valid(session) or payload.size() != 1 or payload[0].get("battle_id") != session.battle_id:
		return
	if id == "battle.attack.hit":
		hits.append(payload[0].duplicate(true))
	if id == "battle.hit.reaction":
		reaction_events.append(payload[0].duplicate(true))

func _hit(context: Dictionary, amount: float = 10.0, kind: StringName = &"normal", priority: int = 100) -> float:
	return target.receive_damage(amount, player, kind, priority, context)
#endregion
#region 原版满值、次数、上限、倍率、模式与重置
func _verify_protection_formula() -> void:
	await _fresh()
	_check(other.protection.maximum == 25000 and target.protection.maximum == 35000, "东皇太一25000与商羊35000分别来自对应Boss，不统一50000")
	_check(demo.get_node("HUD/ProtectionSettings/Column/LeftMaximum").value == 25000.0 and demo.get_node("HUD/ProtectionSettings/Column/RightMaximum").value == 35000.0, "满值UI不因步长量化成25001/35001")
	var bar: ProgressBar = target.feedback.get_node("ProtectionBar")
	_check(bar.visible and bar.max_value == 35000.0, "Boss条显示使用相同的实际满值")
	var context := {"ability_id": &"sunwukong_attack1", "reaction_type": &"none"}
	for n in range(1, 4):
		_hit(context)
		_check(target.protection.last_increment == n * 1000 and target.protection.hit_counts["1001010"] == n, "同目标同技能第%d次命中为1000+1000×(n−1)" % n)
	_check(target.protection.score == 6000 and other.protection.score == 0, "独立目标不共享当前条或技能计数")
	other.receive_damage(1.0, player, &"normal", 100, context)
	_check(other.protection.score == 1000 and other.protection.hit_counts["1001010"] == 1, "相同技能首次命中另一目标重新从1计数")
	context.ability_id = &"sunwukong_attack2"
	_hit(context)
	_check(target.protection.last_increment == 1000 and target.protection.hit_counts["1001020"] == 1, "另一技能有独立次数")
	target.protection.clear()
	context = {"protection_skill_id": "test", "reaction_type": &"none", "protection_parameters": {"protectPoint": 100, "protectPointB": 60, "protectPointMax": 140, "isProtectPointAdd": 1}}
	player.damage_rules.set_source(&"protection.multiplier", {"protectionMultiplier": 1.25})
	_hit(context)
	_check(target.protection.last_increment == 125, "保护增量先截断再乘攻击方倍率")
	_hit(context)
	_check(target.protection.last_increment == 175, "递增值先受140上限限制，再乘1.25，不把上限当Boss满值")
	context.protection_parameters.isProtectPointAdd = 0
	_hit(context)
	_check(target.protection.last_increment == 125, "isProtectPointAdd=0固定n=1")
	context.protection_parameters.protectPoint = 0
	_hit(context)
	_check(target.protection.last_increment == 0 and target.protection.hit_counts["test"] == 3, "零增量不增加技能累计次数")
	player.damage_rules.remove_source(&"protection.multiplier")
	target.protection.clear()
	context = {"protection_skill_id": "1103122", "reaction_type": &"none", "protection_parameters": {"protectPoint": 10, "protectPointB": 10, "isProtectPointAdd": 1}}
	_hit(context)
	context.protection_skill_id = "1103124"
	_hit(context)
	_check(target.protection.last_increment == 20 and target.protection.hit_counts["1103121"] == 2, "原版1103122—25子技能合并到1103121")
	context.protection_skill_id = "custom"
	context.protection_parameters.addXpBySkillId = 1103121
	_hit(context)
	_check(target.protection.last_increment == 30, "addXpBySkillId重定向到已有主技能次数")
	await _step(1, 2.99)
	_check(target.protection.score > 0, "普通模式未受击不足3秒不清空")
	await _step(1, 0.01)
	_check(target.protection.score == 0 and target.protection.hit_counts.is_empty(), "满3战斗秒未受击清空当前、被动保护和次数")
	target.protection_profile.use_as_armor = true
	_hit(context)
	await _step(1, 3.5)
	_check(target.protection.score == 10, "护甲模式不采用普通模式三秒清零")
	target.protection_profile.use_as_armor = false
	target.protection_profile.multiplayer_enemy = true
	target.protection.configure(target, target.protection_profile)
	_check(target.protection.maximum == 63000, "商羊35000的多人敌方实际满值为int(35000×1.8)")
	await _fresh()
	demo.set_protection_maximum(1, 300)
	_check(demo.get_node("HUD/ProtectionSettings/Column/RightMaximum").value == 300.0, "程序修改保护满值同步UI，且不会递归触发修改")
	context = {"protection_skill_id": "cap", "reaction_type": &"none", "protection_parameters": {"protectPoint": 100, "protectPointB": 100, "isProtectPointAdd": 1}}
	_hit(context)
	_hit(context)
	_check(target.protection.trigger_count == 1 and target.protection.previous_score == 300 and target.protection.score == 0 and target.protection.hit_counts.is_empty(), "保护触发记录300、清当前/被动累计及目标技能次数")
	_check(target.action_state.current == State.PROTECT and target.protection.active, "保护触发使用真正Core PROTECT，普通受击不能覆盖")
	await _step(60)
	_hit(context)
	_check(target.protection.last_increment == 100 and target.protection.hit_counts["cap"] == 1, "保护结束后同技能重新从第1次命中开始")
	target.protection.clear()
	target.protection_profile.use_as_armor = true
	target.protection_profile.protection_action_enabled = false
	_hit(context)
	_hit(context)
	_check(not target.protection.active and target.protection.score == 300 and target.protection.hit_counts.is_empty(), "护甲保护动作失败恢复触发前条值，但重置技能次数")
	await _fresh()
	var result := target.protection.register_hit({"protection_skill_id": "pvp", "is_pvp": true, "protection_parameters": {"pvpProtectPoint": 10, "pvpProtectPointB": 10, "pvpProtectPointMax": 15, "isProtectPointAdd": 1}}, 100.0, 10000.0)
	_check(result.increment == 510, "PvP字段加int(伤害/最大生命×50000)；不把50000当Boss满值")
	await _fresh()
	target.protection_profile.maximum_override = -1
	target.protection_profile.original_boss_key = "ChapterRole/209000001"
	_check(target.protection.configure(target, target.protection_profile) and target.protection.maximum == 50000 and not target.protection.show_protect, "Boss原版showProtect=false时不显示条，即使有合法满值")
#endregion
#region 自动退出的真实图形预览（仅显式参数启用）
func _capture_previews() -> void:
	# 只在截图期间隐藏日志浮层，不改 Panku 模块选项或用户持久化配置。
	var overlay: Control = null
	var was_visible := false
	var console := get_node_or_null("/root/Panku") as PankuConsole
	if console != null and console.module_manager.has_module("native_logger"):
		overlay = (console.module_manager.get_module("native_logger") as PankuModuleNativeLogger).output_overlay
		was_visible = overlay.visible
		overlay.hide()
	await _fresh()
	_hit({"reaction_type": &"none", "ability_id": &"sunwukong_attack1"})
	await _step(1)
	await _capture("stage9-preview.png")
	_hit({"launch_speed": 520.0, "knockdown": true}, 10.0, &"launch")
	await _step(12)
	await _capture("stage9-launched.png")
	await _step(65)
	await _capture("stage9-knockdown.png")
	await _step(70)
	demo.set_protection_maximum(1, 1000)
	_hit({"ability_id": &"sunwukong_attack1"})
	await _step(3)
	await _capture("stage9-protect.png")
	if is_instance_valid(overlay):
		overlay.visible = was_visible

func _capture(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png("res://.godot/" + filename)
	_check(result == OK, "真实D3D12截图保存：" + filename)
#endregion
#region HP、霸体、无敌、零伤害与单次结果不能耦合
func _verify_reaction_and_policies() -> void:
	await _fresh()
	var health := target.attributes.get_vital_value(&"health")
	_hit({"reaction_type": &"none"}, 20.0)
	_check(target.attributes.get_vital_value(&"health") == health - 20.0 and target.action_state.current == State.IDLE, "反应none只扣血，不进入硬直")
	demo.set_target_mode(1)
	var before := target.position
	_hit({"hit_stun": 0.2, "knockback_speed": 500.0, "knockback_duration": 0.2, "launch_speed": 400.0}, 20.0, &"launch")
	_check(target.attributes.get_vital_value(&"health") == health - 30.0 and target.action_state.current == State.IDLE and target.motion.impulse_remaining == 0.0, "配置霸体扣血50%，抵抗硬直/击退/浮空而不免疫伤害")
	await _step(15)
	_check(target.position.is_equal_approx(before), "霸体抵抗没有偷偷移动物理体")
	demo.set_target_mode(2)
	target.damage_rules.grant_shield(&"test", 100.0)
	var score := target.protection.score
	_hit({"hit_stun": 0.2, "knockback_speed": 500.0, "knockback_duration": 0.2, "hit_stop_seconds": 0.1, "ability_id": &"sunwukong_attack1", "status_ids": [&"normal_shield"]}, 20.0)
	_check(target.attributes.get_vital_value(&"health") == health - 30.0 and target.damage_rules.get_shield_total() == 100.0, "无敌在Vital前阻止扣血及护盾消耗")
	_check(target.protection.score == score and target.motion.impulse_remaining == 0.0 and session.clock.hit_stop_remaining == 0.0, "默认无敌明确阻止保护累计、位移与受击停顿")
	_check(target.statuses.get_active_statuses().is_empty(), "默认无敌不施加附加GAS状态")
	demo.set_target_mode(3)
	_hit({"hit_stun": 0.2, "knockback_speed": 100.0, "knockback_duration": 0.1}, 20.0)
	_check(target.attributes.get_vital_value(&"health") == health - 30.0 and target.action_state.current == State.HURT and target.motion.impulse_speed == 100.0, "显式免伤但允许动作反应：HP不变，硬直与击退可生效")
	await _fresh()
	health = target.attributes.get_vital_value(&"health")
	_hit({"hit_stun": 0.2}, 0.0)
	_check(target.action_state.current == State.HURT and target.attributes.get_vital_value(&"health") == health, "零伤害动作命中仍可硬直，不以扣血判断动作反应")
	await _fresh()
	target.super_armor = true
	_hit({"hit_stun": 0.2}, 20.0)
	_check(target.attributes.get_vital_value(&"health") == health - 20.0 and target.action_state.current == State.IDLE, "默认霸体倍率1.0照常扣血，只抵抗配置内的打断种类")
	await _fresh()
	demo.set_protection_maximum(1, 1000)
	_hit({"ability_id": &"sunwukong_attack1"})
	_check(target.protection.active and target.action_state.current == State.PROTECT, "触发命中的普通硬直不覆盖保护动作")
	var protected_hp := target.attributes.get_vital_value(&"health")
	_hit({"hit_stun": 0.4, "knockback_speed": 200.0, "knockback_duration": 0.1, "ability_id": &"sunwukong_attack1"})
	_check(target.attributes.get_vital_value(&"health") == protected_hp - 10.0 and target.action_state.current == State.PROTECT and target.motion.impulse_remaining == 0.0 and target.protection.hit_counts.is_empty(), "普通保护不免伤，只阻止动作与位移；保护中不累计次数")
	target.protection.profile.blocks_displacement = false
	_hit({"knockback_speed": 200.0, "knockback_duration": 0.1})
	_check(target.action_state.current == State.PROTECT and target.motion.impulse_remaining == 0.1, "保护可配置仅防硬直却允许位移，不被Core高优先级隐式禁止")
	target.protection.profile.blocks_damage = true
	protected_hp = target.attributes.get_vital_value(&"health")
	_hit({}, 20.0)
	_check(target.attributes.get_vital_value(&"health") == protected_hp, "保护免伤必须显式启用，不与霸体或动作锁混用")
	await _fresh()
	target.reaction_profile.knockback_resistance = 0.5
	target.reaction_profile.launch_resistance = 0.25
	target.reaction_profile.stun_resistance = 0.5
	_hit({"hit_stun": 0.4, "knockback_speed": 200.0, "knockback_duration": 0.1, "launch_speed": 400.0}, 10.0, &"launch")
	_check(target.motion.impulse_speed == 100.0 and target.velocity.y == -300.0 and target.action_state.active_rules.hurt_lock_seconds == 0.2, "目标规则独立缩放击退、浮空与硬直")
	await _fresh()
	var info := DamageCalculator.calculate_damage(target, player, player.damage_context)
	target.receive_damage_info(info, &"normal", 100, {"hit_stun": 0.2})
	await _step(2)
	var elapsed := target.action_state.elapsed
	var hp := target.attributes.get_vital_value(&"health")
	target.receive_damage_info(info, &"normal", 100, {"hit_stun": 0.2})
	_check(target.attributes.get_vital_value(&"health") == hp and target.action_state.elapsed == elapsed, "重复应用同一single_use结果不再次扣血/刷新硬直")
	var dodge := DamageInfo.new(player)
	dodge.is_dodged = true
	dodge.final_damage = 100.0
	target.receive_damage_info(dodge, &"launch", 100, {"launch_speed": 900.0, "ability_id": &"sunwukong_attack1"})
	_check(target.velocity.y == 0.0 and target.protection.score == 0, "闪避不浮空、不累计保护")
#endregion
#region 真实击退、边界、平台与动作生命周期
func _verify_physics_and_lifecycle() -> void:
	await _fresh()
	target.protection.profile.enabled = false
	var initial := target.position
	_hit({"hit_stun": 0.3, "knockback_mode": &"displacement", "knockback_distance": 30.0, "knockback_duration": 0.2, "knockback_direction": &"away_from_attacker"})
	await _step(15)
	_check(absf(target.position.x - initial.x - 30.0) < 0.01, "定距击退按30/0.2速度推进，仅走30像素，不额外多走最后一tick")
	target.position = Vector2(1250, 650)
	await _step(2)
	_hit({"hit_stun": 0.5, "knockback_speed": 5000.0, "knockback_duration": 0.5})
	await _step(1, 0.5)
	_check(target.get_body_rect_global().end.x <= 1285.1 and target.position.x > 1250.0, "巨大delta高速击退经过真实扫掠，不穿越右墙")
	await _fresh()
	target.protection.profile.enabled = false
	target.position = Vector2(-380, 650)
	await _step(2)
	_hit({"hit_stun": 0.4, "knockback_speed": 5000.0, "knockback_duration": 0.4, "knockback_direction": &"explicit", "knockback_sign": -1})
	await _step(1, 0.4)
	_check(target.get_body_rect_global().position.x >= -405.1, "显式左向高速击退不穿越左墙")
	await _fresh()
	target.protection.profile.enabled = false
	target.position = Vector2(950, 525)
	target.motion.grounded = false
	target.velocity = Vector2.ZERO
	await _step(12)
	_check(target.motion.grounded and absf(target.position.y - 530.0) < 1.0, "目标由上方实际落在单向平台上")
	_hit({"hit_stun": 0.15, "knockback_speed": 500.0, "knockback_duration": 0.5, "attack_facing": 1})
	var air_seen := false
	for tick in range(75):
		await _step()
		air_seen = air_seen or target.action_state.current == State.AIR_HURT
	_check(air_seen and target.motion.grounded and target.position.y > 640.0, "击退跨平台边缘保持受击下落，最终由物理落到地面")
	await _fresh()
	target.protection.profile.enabled = false
	_hit({"reaction_type": &"launch", "launch_speed": 520.0, "hit_stun": 0.05, "knockdown": true}, 10.0, &"launch")
	_check(target.action_state.current == State.LAUNCHED and target.animation.get_current_action() == &"launched", "击飞立即进入专用Core叶子与可预览动画")
	_check(not target.try_jump() and not target.request_attack(), "受击空中阶段不能用正常跳跃/攻击解锁")
	var seen := {State.LAUNCHED: true}
	for tick in range(140):
		await _step()
		seen[target.action_state.current] = true
		if target.action_state.current in [State.LAUNCHED, State.AIR_HURT, State.HIT_LAND, State.KNOCKDOWN, State.GETUP]:
			_check(not target.action_state.get_permission(&"move", target.action_profile), "受击各阶段均禁止操控移动")
	for phase in [State.AIR_HURT, State.HIT_LAND, State.KNOCKDOWN, State.GETUP, State.IDLE]:
		_check(seen.has(phase), "击飞按顺序经历空中受击/落地/倒地/起身/待机：%s" % BattleActionLeafState2D.NAMES[phase])
	_check(target.motion.grounded and is_zero_approx((target.get_node("AnimationAdapter/Visual/Body") as Node2D).rotation), "起身结束还原姿态，并由Core而非动画信号解锁")
	_hit({"launch_speed": 450.0, "knockdown": true}, 10.0, &"launch")
	_hit({}, 50000.0, &"death", 10000)
	await _step(50)
	_check(target.action_state.current == State.DEAD and not target.protection.active and target.motion.impulse_remaining == 0.0, "死亡终态覆盖受击/浮空/倒地/保护，不会起身复活")
#endregion
#region 真实五段技能、连续命中与统一受击停顿
func _verify_native_attacks_and_clock() -> void:
	await _fresh()
	for cast in range(8):
		_check(player.try_activate_skill(&"sunwukong_attack1"), "通过真实GAS重复施放普攻%d" % (cast + 1))
		await _step(40)
	_check(hits.size() == 8 and target.protection.trigger_count == 1 and target.protection.previous_score == 36000, "跨8次实际施放同技能累计36k触发商羊35k保护，非每次释放重置")
	await _fresh()
	target.protection.profile.enabled = false
	for step in range(1, 6):
		demo.place_near()
		_check(player.try_activate_skill(StringName("sunwukong_attack%d" % step)), "真实技能启动第%d攻击段" % step)
		await _step(46)
	_check(hits.size() >= 5 and reaction_events.size() >= 5, "不同真实攻击段产生命中与独立动作反应")
	_check(reaction_events.any(func(row): return row.launch_speed == 520.0) and reaction_events.any(func(row): return row.knockback_speed == 90.0) and reaction_events.any(func(row): return row.knockback_speed == 100.0), "真实攻击段传递90速度、定距击退及520浮空，不是统一反应")
	await _fresh()
	# 同一范围内两个目标均应结算；第一个目标请求停顿不能阻止后一个。
	other.position = target.position + Vector2(-30, 0)
	player.try_activate_skill(&"sunwukong_attack1")
	await _step(8)
	_check(hits.size() == 2 and session.clock.hit_stop_remaining > 0.0, "同tick两目标先完成命中，再统一开始hit-stop")
	var position := target.position
	var animation_time := target.animation.get_playback_time()
	var score := target.protection.score
	var inactivity := target.protection.inactive_seconds
	await _step(1, 0.01)
	_check(target.position == position and target.animation.get_playback_time() == animation_time and target.protection.score == score and target.protection.inactive_seconds == inactivity, "受击停顿同时冻结物理、动画、硬直与保护计时")
	session.set_paused(true)
	var stop := session.clock.hit_stop_remaining
	await _step(1, 0.5)
	_check(session.clock.hit_stop_remaining == stop, "菜单暂停也冻结停顿剩余时间")
	session.set_paused(false)
	await _step(3)
	session.set_time_scale(0.5)
	var before := target.protection.inactive_seconds
	await _step(1, 0.2)
	_check(is_equal_approx(target.protection.inactive_seconds - before, 0.1), "保护与动作共用战斗秒，慢动作0.5倍")
#endregion
