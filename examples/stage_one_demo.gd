extends Node
#region 演示运行状态
var _session: BattleSession
var _first: BattleEntity
var _second: BattleEntity
var _summary: Label
var _first_label: Label
var _second_label: Label
var _event_label: Label
var _pause_button: Button
var _last_event: String = "等待技能原素材第 12 帧事件"
#endregion
#region 生命周期与界面
func _ready() -> void:
	_session = BattleSystem.create_session(self, "", 4399)
	if _session == null:
		return
	_build_interface()
	CoreSystem.event_bus.subscribe("battle.skill.marker", _on_skill_marker)
	_reset_entities()

func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var backdrop := ColorRect.new()
	backdrop.color = Color("101928")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	canvas.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	margin.add_child(column)
	_label(column, "阶段 1 · 配置、实体与战斗时钟", 30)
	_label(column, "A 与 B 使用同一角色定义；生命、技能冷却、状态各自独立。B 的阵营覆盖为 enemy。", 18)
	_summary = _label(column, "", 20)
	var entities := HBoxContainer.new()
	entities.add_theme_constant_override("separation", 24)
	column.add_child(entities)
	_first_label = _entity_panel(entities, "实体 A")
	_second_label = _entity_panel(entities, "实体 B")
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	column.add_child(actions)
	_button(actions, "A 释放技能", _cast_first)
	_button(actions, "B 添加减伤状态", _guard_second)
	_button(actions, "停顿 0.3 秒", _hit_stop)
	_button(actions, "重建两个实例", _reset_entities)
	var times := HBoxContainer.new()
	times.add_theme_constant_override("separation", 12)
	column.add_child(times)
	_pause_button = _button(times, "暂停", _toggle_pause)
	_button(times, "0.5× 慢动作", _slow)
	_button(times, "1× 正常时间", _normal)
	_event_label = _label(column, "", 18)
	_label(column, "素材 30 fps：第 12 帧 = 0.4 秒，第 18 帧 = 0.6 秒。\n逻辑使用 60 Hz 固定物理更新；暂停、慢动作、停顿同时影响技能、冷却、Buff、恢复与位移。\n示例数值用于验证接口，并非原版角色数据。", 18)

func _label(parent: Node, value: String, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("e5edf9"))
	parent.add_child(label)
	return label

func _entity_panel(parent: Node, title: String) -> Label:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(0, 210)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("203047")
	style.content_margin_left = 24
	style.content_margin_top = 18
	style.content_margin_right = 24
	style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return _label(panel, title, 20)

func _button(parent: Node, title: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 42
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _process(_delta: float) -> void:
	if not is_instance_valid(_session) or _summary == null:
		return
	_summary.text = "战斗时间 %.3f s  |  固定物理 tick %d  |  缩放 %.1f×  |  停顿剩余 %.3f s" % [_session.clock.elapsed, _session.clock.physics_tick, _session.clock.time_scale, _session.clock.hit_stop_remaining]
	_first_label.text = _describe_entity("实体 A", _first)
	_second_label.text = _describe_entity("实体 B", _second)
	_event_label.text = _last_event
	_pause_button.text = "恢复" if _session.clock.paused else "暂停"
#endregion
#region 演示交互
func _reset_entities() -> void:
	_session.clear_battle()
	_session.set_paused(false)
	_session.set_time_scale(1.0)
	_first = _session.spawn_entity("characters", &"sample_hero", Vector3(-5, 0, 0))
	_second = _session.spawn_entity("characters", &"sample_hero", Vector3(5, 0, 0), &"enemy")
	_last_event = "新实例已生成，运行 ID 不复用，战斗时间保持连续。"

func _cast_first() -> void:
	_last_event = "A 技能已启动，等待第 12 帧。" if _first.try_activate_skill(&"sample_attack") else "当前暂停、停顿或技能仍在冷却。"

func _guard_second() -> void:
	if not _session.is_simulation_blocked():
		_second.apply_status_definition(&"sample_guard")

func _toggle_pause() -> void:
	_session.set_paused(not _session.clock.paused)

func _slow() -> void:
	_session.set_time_scale(0.5)

func _normal() -> void:
	_session.set_time_scale(1.0)

func _hit_stop() -> void:
	_session.request_hit_stop(0.3)

func _on_skill_marker(context: Dictionary) -> void:
	if context.battle_id != _session.battle_id or context.source_entity_id != _first.entity_id:
		return
	_last_event = "Core 事件 #%d：素材帧 %d，技能时间 %.2f s，战斗时间 %.3f s" % [context.sequence, context.source_frame, context.skill_time, context.combat_time]
	if context.source_frame == 12:
		var info := DamageInfo.new(_first, _first.abilities, DamageCalculator.calculate_final_damage(_second, _first, {}))
		info.final_damage = info.base_damage
		var applied := (_second.attributes.get_vital(&"health") as HealthVital).apply_damage(info, _second)
		_last_event += "；B 实际受到 %.1f 伤害。" % applied

func _describe_entity(title: String, entity: BattleEntity) -> String:
	if not is_instance_valid(entity):
		return title
	var ability := entity.abilities.get_ability_instance(&"sample_attack")
	var cooldown := ability.get_feature("CooldownFeature") as CooldownFeature
	var guard := entity.statuses.get_status(&"sample_guard")
	return "%s  |  %s\n配置 ID：%s\n运行序号：%s\n生命：%.1f / %.1f\n技能冷却：%.2f s\n减伤状态：%s" % [title, entity.faction_id, entity.definition_id, String(entity.entity_id).get_file(), entity.attributes.get_vital_value(&"health"), entity.attributes.get_value(&"hpMax"), cooldown.get_cooldown_remaining(ability), "%.2f s / %d 层" % [guard.remaining_duration, guard.stacks] if guard != null else "无"]

func _exit_tree() -> void:
	CoreSystem.event_bus.unsubscribe("battle.skill.marker", _on_skill_marker)
	if is_instance_valid(_session):
		_session.clear_battle()
#endregion
