extends GameplayVitalAttributeComponent
class_name BattleAttributeComponent
#region 属性链运行状态
## 最终值仍由 GAS GameplayAttributeInstance 计算；此组件只管理成长与来源。
var progression: BattleAttributeProgression
var _sources: Dictionary[StringName, Array] = {}
var _inventory: C_Inventory
var _refill_after_level: bool = false
var _configured: bool = false
var _pending_vital_snapshot: bool = false
signal snapshot_changed(snapshot: Dictionary)
#endregion
#region 初始化与统一通知
func configure_progression(data: BattleAttributeProgression, initial_level: int) -> void:
	progression = data
	_configured = true
	attributes_recalculated.connect(_on_recalculated)
	vital_value_changed.connect(_on_vital_changed)
	set_level(initial_level)
	if has_attribute(&"level"):
		super.set_base_value(&"level", current_level)

func _on_recalculated(_changes: Dictionary) -> void:
	_pending_vital_snapshot = false
	var snapshot := get_snapshot()
	snapshot_changed.emit(snapshot.duplicate(true))
	var owner := get_parent()
	if is_instance_valid(owner) and owner.has_method("publish_battle_event"):
		owner.publish_battle_event(&"battle.attributes.changed", {"attributes": snapshot})

func _on_vital_changed(_id: StringName, _value: float, _maximum: float, _percent: float, _regen: bool) -> void:
	# 属性事务会在完成时发布完整快照；单独伤害、耗蓝和回复也即时通知面板。
	if _update_depth == 0 and not _notifying_attributes:
		_on_recalculated({})
	else:
		_pending_vital_snapshot = true

func end_update() -> void:
	super.end_update()
	# 只包含治疗/耗蓝的效果事务也要通知，不能依赖普通属性发生变化。
	if _update_depth == 0 and _pending_vital_snapshot and not _notifying_attributes:
		_on_recalculated({})

func get_snapshot() -> Dictionary:
	var result := {}
	for id in _attributes:
		result[id] = get_value(id)
	result[&"hp"] = get_vital_value(&"health") if has_vital(&"health") else 0.0
	result[&"mp"] = get_vital_value(&"mana") if has_vital(&"mana") else 0.0
	result[&"level"] = current_level
	result[&"expNext"] = progression.get_required_experience(current_level) if progression != null else 0.0
	return result
#endregion
#region 基础、成长、等级和经验
func set_base_value(id: StringName, value: float) -> bool:
	if not is_finite(value):
		return false
	if id == &"level":
		set_level(int(value))
		return true
	if id == &"exp":
		set_experience(value)
		return has_attribute(id)
	return super.set_base_value(id, value)

func _set_current_level(value: int) -> void:
	if not _configured:
		super._set_current_level(value)
		return
	var limit := progression.maximum_level if progression != null else 10000
	value = clampi(value, 1, limit)
	if value == current_level:
		return
	begin_update()
	_refill_after_level = value > (_pending_level_from if _pending_level_from >= 0 else current_level)
	super._set_current_level(value)
	if progression != null:
		var modifiers: Array[GameplayAttributeModifier] = []
		for id in progression.growth_per_level:
			modifiers.append(GameplayAttributeModifier.new(id, progression.growth_per_level[id] * (value - 1)))
		replace_source(&"growth.level", modifiers)
	if has_attribute(&"level"):
		super.set_base_value(&"level", value)
	end_update()

## exp 是本等级剩余经验，沿用 UserVO.updateExp 的逐级扣除流程。
func set_experience(value: float) -> void:
	if not has_attribute(&"exp") or not is_finite(value):
		return
	begin_update()
	var remaining := maxf(0.0, floorf(value))
	var level := current_level
	if progression != null:
		while level < progression.maximum_level:
			var required := progression.get_required_experience(level)
			if required <= 0.0 or remaining < required:
				break
			remaining -= required
			level += 1
	super.set_base_value(&"exp", remaining)
	set_level(level)
	end_update()

func add_experience(amount: float) -> void:
	if has_attribute(&"exp"):
		set_experience(get_value(&"exp") + amount)

func _after_attribute_notifications() -> void:
	if not _refill_after_level:
		return
	_refill_after_level = false
	# 原版升级回满 hpMax/mpMax（基础+成长+装备），临时 Buff 上限不参与补充。
	for id in [&"health", &"mana"]:
		if has_vital(id):
			var vital := get_vital(id)
			# 属性升级不能使死亡状态复活。
			if id != &"health" or vital.current_value > 0.0:
				vital.set_current_value(get_layer_value(vital.max_value_attribute, false))
#endregion
#region 装备和临时属性来源
## 替换同来源而非叠加；资源模板始终先复制。
func replace_source(source: StringName, modifiers: Array[GameplayAttributeModifier]) -> void:
	if source.is_empty():
		return
	begin_update()
	remove_modifiers_by_source(source)
	for template in modifiers:
		if template != null and is_finite(template.value):
			var modifier := template.duplicate() as GameplayAttributeModifier
			modifier.source_id = source
			add_modifier(modifier)
	end_update()

func set_equipment(slot: StringName, definition: BattleEquipmentDefinition) -> void:
	var mods: Array[GameplayAttributeModifier] = []
	if definition != null:
		mods = definition.attribute_modifiers
	replace_source(StringName("equipment." + String(slot)), mods)

func bind_inventory(inventory: C_Inventory) -> void:
	begin_update()
	if is_instance_valid(_inventory):
		_inventory.equip_changed.disconnect(_on_inventory_equipped)
		for slot in _inventory.equip_slots:
			replace_source(StringName("equipment." + slot), [])
	_inventory = inventory
	if is_instance_valid(_inventory):
		_inventory.equip_changed.connect(_on_inventory_equipped)
		for slot in _inventory.equip_slots:
			_on_inventory_equipped(slot, _inventory.equip_slots[slot][1])
	end_update()

func _on_inventory_equipped(slot: StringName, item: Equip) -> void:
	set_equipment(slot, item.battle_definition if item is BattleInventoryEquipment else null)

func add_modifier(modifier: GameplayAttributeModifier) -> void:
	if modifier == null or not is_finite(modifier.value) or not has_attribute(modifier.attribute_id) or modifier.attribute_id in [&"level", &"exp"]:
		return
	if _sources.get(modifier.source_id, []).has(modifier):
		return
	if not _sources.has(modifier.source_id):
		_sources[modifier.source_id] = []
	_sources[modifier.source_id].append(modifier)
	super.add_modifier(modifier)

func remove_modifier(modifier: GameplayAttributeModifier) -> void:
	if modifier == null or not _sources.get(modifier.source_id, []).has(modifier):
		return
	_sources[modifier.source_id].erase(modifier)
	if _sources[modifier.source_id].is_empty():
		_sources.erase(modifier.source_id)
	super.remove_modifier(modifier)

func remove_modifiers_by_source(source: StringName) -> void:
	begin_update()
	_sources.erase(source)
	super.remove_modifiers_by_source(source)
	end_update()

func get_layer_value(id: StringName, include_temporary: bool = true) -> float:
	var instance := get_attribute(id)
	if instance == null:
		return 0.0
	if include_temporary:
		return get_value(id)
	var value := instance.base_value
	var multiplier := 0.0
	var override_value: float = NAN
	for source in _sources:
		if not include_temporary and not (String(source).begins_with("growth.") or String(source).begins_with("equipment.")):
			continue
		for modifier: GameplayAttributeModifier in _sources[source]:
			if modifier.attribute_id != id:
				continue
			match modifier.modifier_type:
				GameplayAttributeModifier.ModifierType.ADD: value += modifier.value
				GameplayAttributeModifier.ModifierType.MULTIPLY: multiplier += modifier.value
				GameplayAttributeModifier.ModifierType.OVERRIDE:
					if is_nan(override_value):
						override_value = modifier.value
	value *= 1.0 + multiplier
	if not is_nan(override_value):
		value = override_value
	if instance.attribute_def.round_final_value:
		value = floorf(value + 0.5)
	return clampf(value, instance.attribute_def.min_value, instance.attribute_def.max_value)

func get_breakdown(id: StringName) -> Dictionary:
	var instance := get_attribute(id)
	if instance == null:
		return {}
	var result := {"base": instance.base_value, "growth": [], "equipment": [], "temporary": [], "final": get_value(id)}
	for source in _sources:
		var layer := "growth" if String(source).begins_with("growth.") else ("equipment" if String(source).begins_with("equipment.") else "temporary")
		for modifier: GameplayAttributeModifier in _sources[source]:
			if modifier.attribute_id == id:
				result[layer].append({"source": source, "type": modifier.modifier_type, "value": modifier.value})
	return result
#endregion
