extends Control
class_name BattleOriginalHUD
#region 共享关卡UI只读角色/GAS；菜单获得控制权并释放缓存
signal inventory_changed(open: bool)
signal module_changed(open: bool)
signal settings_requested
signal module_requested(module: StringName)
@export var disabled_icon_material: ShaderMaterial
var actor: BattleEntity2D
var session: BattleSession
var _rage_target: float = 0.0
var _rage_from: float = 0.0
var _rage_age: float = 1.0
var _wushuang_full: bool = false
var _cooldowns: Array[CooldownFeature] = []
var _abilities: Array[GameplayAbilityInstance] = []
var _notice_entries: Dictionary = {}
var _notice_pending: Array[Control] = []
var _last_notification: Control
var _visible_statuses: Array[GameplayStatusInstance] = []
@onready var inventory_view: OriginalInventoryView = $Inventory

func _ready() -> void:
	for button in $BattleTools.get_children():
		button.pressed.connect(open_module.bind(StringName(button.get_meta(&"module"))))
	$ModulePanel/Close.pressed.connect(func(): set_module_open(false))
	inventory_view.close_requested.connect(func(): set_inventory_open(false))
	CoreSystem.event_bus.event_pushed.connect(_on_event)
	CoreSystem.operation_manager.bindings.mapping_changed.connect(_on_mapping_changed)

func bind_actor(owner_actor: BattleEntity2D) -> void:
	actor = owner_actor
	session = actor.session
	$HitCombo.bind_tracker(session.hit_combo, actor.entity_id)
	inventory_view.bind_actor(actor)
	(inventory_view.inventory as OriginalInventory).operation_rejected.connect(show_notification)
	(inventory_view.inventory as OriginalInventory).operation_completed.connect(show_notification)
	actor.attributes.snapshot_changed.connect(_refresh_attributes)
	actor.statuses.status_applied.connect(_refresh_status_icons)
	actor.statuses.status_removed.connect(_refresh_status_icons)
	actor.statuses.status_stacked.connect(_refresh_status_icons)
	for index in range($Player/StatusIcons.get_child_count()):
		var slot := $Player/StatusIcons.get_child(index) as Control
		slot.mouse_entered.connect(_show_status_tip.bind(index))
		slot.mouse_exited.connect(func(): $SkillTooltip.hide())
	_refresh_status_icons()
	_refresh_attributes(actor.attributes.get_snapshot())
	for index in range(5):
		var slot := $Skills/Slots.get_child(index) as Control
		var intent := StringName("skill_%d" % (index + 1))
		var id: StringName = actor.operations.ability_slots.get(intent, &"")
		var ability := actor.abilities.get_ability_instance(id)
		_abilities.append(ability)
		var cooldown: CooldownFeature
		if ability != null:
			slot.get_node("Icon").texture = ability.get_definition().icon
			for feature in ability.get_definition().features:
				if feature is CooldownFeature: cooldown = feature; break
			slot.mouse_entered.connect(_show_skill_tip.bind(index))
			slot.mouse_exited.connect(func(): $SkillTooltip.hide())
		_cooldowns.append(cooldown)
	if actor.wushuang != null and actor.wushuang.rage != null:
		actor.wushuang.rage.value_changed.connect(_on_rage_changed)
		_on_rage_changed(0, 0, actor.wushuang.rage.get_percent(), false)
	_refresh_keys()

func _refresh_attributes(snapshot: Dictionary) -> void:
	$Player/HP.value = clampf(float(snapshot.hp) / maxf(1, snapshot.hpMax), 0, 1)
	$Player/MP.value = clampf(float(snapshot.mp) / maxf(1, snapshot.mpMax), 0, 1)
	$Player/EXP.value = clampf(float(snapshot.get(&"exp", 0)) / maxf(1, snapshot.expNext), 0, 1)
	$Player/HPText.text = "%d/%d" % [roundi(snapshot.hp), roundi(snapshot.hpMax)]
	$Player/MPText.text = "%d/%d" % [roundi(snapshot.mp), roundi(snapshot.mpMax)]
	$Player/EXPText.text = "%d/%d" % [roundi(snapshot.get(&"exp", 0)), roundi(snapshot.expNext)]
	$Player/Level.text = str(int(snapshot.level))

func _refresh_keys() -> void:
	if actor == null: return
	for index in range(5):
		$Skills/Slots.get_child(index).get_node("Key").text = get_intent_key(StringName("skill_%d" % (index + 1)))
	$Skills/WushuangKey.text = get_intent_key(&"wushuang")
	_refresh_wushuang_full()
	for index in range(2): $Skills.get_node("ItemKey%d" % index).text = get_intent_key(StringName("item_%d" % (index+1)))

func _refresh_status_icons(_id: StringName = &"", _change: Variant = null) -> void:
	_visible_statuses.clear()
	for status in actor.statuses.get_active_statuses():
		if not status.removed and status.status_data.icon != null: _visible_statuses.append(status)
	for index in range($Player/StatusIcons.get_child_count()):
		var slot := $Player/StatusIcons.get_child(index) as Control
		slot.visible = index < _visible_statuses.size()
		var status: GameplayStatusInstance = _visible_statuses[index] if slot.visible else null
		slot.get_node("Icon").texture = status.status_data.icon if status != null else null
		slot.get_node("Count").text = str(status.stacks) if status != null and (status.stacks > 1 or status.status_data.get_meta(&"original_fold", false)) else ""

func _show_status_tip(index: int) -> void:
	if inventory_view.visible or index >= _visible_statuses.size(): return
	var status := _visible_statuses[index]
	$SkillTooltip/Text.text = "%s\n%s" % [status.status_data.status_display_name, status.status_data.status_description]
	$SkillTooltip.position = Vector2(75+32*index,92)
	$SkillTooltip.show()

func _has_skill_resources(ability: GameplayAbilityInstance) -> bool:
	if ability == null: return false
	# RoleSkillView按HP/MP消耗变灰；CD由独立遮罩显示，动作锁定不把整排图标染暗。
	var context := {"ability_component":actor.abilities,"instigator":actor}
	for feature in ability.get_definition().features:
		if feature is CostFeature and not feature.can_activate(ability,context): return false
	return true

func _show_skill_tip(index: int) -> void:
	if inventory_view.visible or _abilities[index] == null: return
	var ability := _abilities[index]
	var remaining := _cooldowns[index].get_cooldown_remaining(ability) if _cooldowns[index] != null else 0.0
	$SkillTooltip/Text.text = "%s\n按键：%s\n剩余冷却：%d秒" % [ability.get_definition().ability_name, get_intent_key(StringName("skill_%d" % (index + 1))), ceili(remaining)]
	$SkillTooltip.position = Vector2(65 + index * 41, 395)
	$SkillTooltip.show()

func get_intent_key(intent: StringName) -> String:
	var actions := actor.operations.operation_profile.get_actions(intent)
	if actions.is_empty(): return ""
	var events := InputMap.action_get_events(actions[0])
	if events.is_empty(): return ""
	var event := events[0]
	if event is InputEventKey:
		var key := OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
		return "空格" if key == "Space" else key
	return event.as_text()

func _on_mapping_changed(_action: StringName) -> void:
	_refresh_keys()

func set_inventory_open(open: bool) -> void:
	if actor == null or open == inventory_view.visible: return
	if open: set_module_open(false)
	actor.operations.set_control_blocked(&"inventory", open)
	$SkillTooltip.hide()
	inventory_view.visible = open
	inventory_changed.emit(open)

#region 原版六个战斗入口；尚未移植的模块显示真实运行数据
func open_module(module: StringName) -> void:
	if actor == null: return
	module_requested.emit(module)
	if module == &"backpack":
		set_inventory_open(not inventory_view.visible)
		return
	set_inventory_open(false)
	set_module_open(false)
	if module == &"systemSet":
		settings_requested.emit()
		return
	if module == &"petHorse":
		show_notification("你还没有灵宠")
		return
	var lines: Array[String] = []
	match module:
		&"skill":
			$ModulePanel/Title.text = "技能"
			for index in range(_abilities.size()):
				var ability := _abilities[index]
				if ability == null: continue
				var remaining := _cooldowns[index].get_cooldown_remaining(ability) if _cooldowns[index] != null else 0.0
				lines.append("%s　按键：%s　冷却：%d秒" % [ability.get_definition().ability_name, get_intent_key(StringName("skill_%d" % (index + 1))), ceili(remaining)])
		&"heartMedical":
			$ModulePanel/Title.text = "心法"
			lines.append("尚未接入心法养成。当前生效的战斗效果：")
			for status in actor.statuses.get_active_statuses():
				if not status.removed: lines.append(status.status_data.status_display_name)
			if lines.size() == 1: lines.append("无")
		&"magicWeapon":
			$ModulePanel/Title.text = "法宝"
			var item := inventory_view.inventory.equip_slots["amulet"][1] as Item
			lines.append("尚未装备法宝" if item == null else item.name)
			lines.append("可在背包中查看和装备法宝。")
		_: return
	$ModulePanel/Text.text = "\n\n".join(lines)
	set_module_open(true)

func set_module_open(open: bool) -> void:
	if actor == null or open == $ModulePanel.visible: return
	actor.operations.set_control_blocked(&"battle_module", open)
	$SkillTooltip.hide()
	$ModulePanel.visible = open
	module_changed.emit(open)

func is_module_open() -> bool:
	return $ModulePanel.visible

func refresh_level_time() -> void:
	if session == null: return
	var seconds := maxi(0, floori(session.level_instance.elapsed if session.level_instance != null else session.clock.elapsed))
	$LevelTimer/Time.text = "%02d:%02d" % [seconds / 60, seconds % 60]
#endregion

func _process(delta: float) -> void:
	if actor == null or not is_instance_valid(actor): return
	refresh_level_time()
	for index in range(_abilities.size()):
		var slot := $Skills/Slots.get_child(index) as Control
		var ability := _abilities[index]
		var cooldown := _cooldowns[index]
		var remaining := cooldown.get_cooldown_remaining(ability) if cooldown != null else 0.0
		var progress := cooldown.get_cooldown_progress(ability) if cooldown != null else 0.0
		slot.get_node("Cooldown").visible = remaining > 0
		# 原cdTime按已过冷却播放：第1帧全遮盖，第101帧清空；GAS返回剩余比例。
		slot.get_node("Cooldown").frame = clampi(floori((1.0 - progress) * 100), 0, 100)
		slot.get_node("Icon").material = null if _has_skill_resources(ability) else disabled_icon_material
	_advance_wushuang_ui(delta)
	$NextScreen/Animation.advance_effect(delta)
	# Flash Timer/TweenLite独立于战斗暂停；背包错误提示仍会正常退出。
	for node in _notice_entries.keys():
		var entry: Dictionary = _notice_entries[node]
		entry.age += delta
		# CreateComponent在1.5秒将队首AutoWarnBar.start(1)，随后一秒淡出。
		if entry.age >= 1.5: _notice_pending.erase(node)
		var t := clampf(entry.age - 1.5, 0, 1)
		node.position.y = entry.base_y - 100 * (1 - pow(1 - t, 2))
		node.modulate.a = pow(1 - t, 2)
		if entry.age >= 2.5:
			node.hide()
			_notice_entries.erase(node)

#region 原版怒气遮罩一秒Quad.easeOut；固定插值状态避免每帧新建Tween
func _on_rage_changed(_value: float, _maximum: float, percent: float, _regen: bool) -> void:
	var next := clampf(percent, 0.0, 1.0)
	if not is_equal_approx(_rage_target, next):
		_rage_from = $Skills/Rage.value
		_rage_target = next
		_rage_age = 0.0
	_refresh_wushuang_full()

func _refresh_wushuang_full() -> void:
	if actor == null: return
	var full := actor.wushuang != null and actor.wushuang.rage != null and not actor.wushuang.using_wushuang and actor.is_alive() and actor.wushuang.rage.get_percent() >= 1.0
	if full != _wushuang_full:
		_wushuang_full = full
		$Skills/WushuangIdle.visible = not full
		if full:
			$Skills/WushuangFull.play_effect()
			$Skills/WushuangPrompt.play_effect()
		else:
			$Skills/WushuangFull.stop_effect()
			$Skills/WushuangPrompt.stop_effect()
	var show_key := full
	if session.level_instance != null and session.level_instance.definition != null:
		show_key = full and int(session.level_instance.definition.get_meta(&"original_level_id", 1)) <= 3
	# 默认空格直接播放原6帧提示；改键后用同一位置的实际键名。
	$Skills/WushuangPrompt.visible = show_key and $Skills/WushuangKey.text == "空格"
	$Skills/WushuangKey.visible = show_key and $Skills/WushuangKey.text != "空格"

func _advance_wushuang_ui(delta: float) -> void:
	_rage_age = minf(1.0, _rage_age + delta)
	$Skills/Rage.value = lerpf(_rage_from, _rage_target, 1.0 - pow(1.0 - _rage_age, 2.0))
	_refresh_wushuang_full()
	$Skills/WushuangFull.advance_effect(delta)
	$Skills/WushuangPrompt.advance_effect(delta)
#endregion

func show_notification(message: String) -> void:
	if _notice_pending.size() > 10: return
	var node: Control
	for candidate in $Notifications.get_children():
		if not candidate.visible: node = candidate; break
	if node == null: return
	var label := node.get_node("Text") as Label
	label.text = message
	var measured := label.get_theme_font("font").get_multiline_string_size(message,HORIZONTAL_ALIGNMENT_CENTER,-1,20)
	var dimensions := Vector2(minf(900,measured.x+80),measured.y+30)
	node.get_node("Background").position = (get_viewport().get_visible_rect().size - dimensions)/2
	node.get_node("Background").size = dimensions
	label.position = node.get_node("Background").position + Vector2(20,15)
	label.size = dimensions - Vector2(40,30)
	node.position.y = 0
	node.modulate.a = 1
	node.show()
	_notice_pending.append(node)
	_notice_entries[node] = {"age":0.0,"base_y":0.0,"height":dimensions.y}
	for index in range(_notice_pending.size()):
		var pending := _notice_pending[index]
		_notice_entries[pending].base_y = -_notice_entries[pending].height*(_notice_pending.size()-1-index)
		pending.position.y = _notice_entries[pending].base_y
	_last_notification = node

func _on_event(id: String, payload: Array) -> void:
	if actor == null or payload.size() != 1 or not payload[0] is Dictionary or payload[0].get("battle_id") != session.battle_id: return
	var data: Dictionary = payload[0]
	if id == "battle.loot.picked_up" and data.source_entity_id == actor.entity_id:
		if not data.get("is_supply", false):
			$PickupEffects.play_pickup(data.screen_position, data.pickup_texture, data.screen_size)
	elif id == "battle.loot.cleared":
		$PickupEffects.clear_effects()
	elif id == "battle.operation_intent" and data.source_entity_id == actor.entity_id and data.phase == "pressed":
		var intent := StringName(data.intent)
		if not String(intent).begins_with("skill_"): return
		var ability := actor.abilities.get_ability_instance(actor.operations.ability_slots.get(intent, &""))
		if ability == null: return
		for feature in ability.get_definition().features:
			if feature is CooldownFeature and feature.get_cooldown_remaining(ability) > 0:
				show_notification("技能尚未冷却")
				return
			if feature is CostFeature:
				for cost in feature.costs:
					if cost is BattleSkillManaCost and not cost.can_pay_context(actor.abilities, actor, {}):
						show_notification("魔法不足")
						return
	elif id == "battle.region.exit_opened":
		# 区域出生计划及目标全完成才前进；最终出口继续使用通关光圈。
		var level := session.level_instance
		if level != null and not level.regions.is_empty() and data.get("region_id") != level.regions[-1].definition.region_id:
			$NextScreen/Animation.play_effect()
	elif id == "battle.boss.execution_finished": show_notification("出口已开启")
	elif id == "battle.level.victory": show_notification("通关成功")
	elif id == "battle.level.failed": show_notification("挑战失败")

func _exit_tree() -> void:
	if CoreSystem.event_bus.event_pushed.is_connected(_on_event): CoreSystem.event_bus.event_pushed.disconnect(_on_event)
	if CoreSystem.operation_manager.bindings.mapping_changed.is_connected(_on_mapping_changed): CoreSystem.operation_manager.bindings.mapping_changed.disconnect(_on_mapping_changed)
#endregion
