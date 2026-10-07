extends RefCounted
class_name BattleGASBinding
#region 共用 GAS 装配
## 2D/3D 实体共享这套装配，组件、Vital 和技能黑板仍各实例独占。
static func attach(owner: Node, session: BattleSession, data: BattleEntityDefinition) -> Array:
	var attributes := BattleAttributeComponent.new()
	var abilities := GameplayAbilityComponent.new()
	var statuses := GameplayStatusComponent.new()
	attributes.name = "GameplayVitalAttributeComponent"
	abilities.name = "GameplayAbilityComponent"
	statuses.name = "GameplayStatusComponent"
	attributes.externally_driven = true
	abilities.externally_driven = true
	statuses.externally_driven = true
	statuses.filter_events_by_owner = true
	owner.add_child(attributes)
	owner.add_child(abilities)
	owner.add_child(statuses)
	var sets: Array[GameplayAttributeSet] = [data.attribute_set]
	if data.progression != null and data.progression.attribute_set != null:
		sets.append(data.progression.attribute_set)
	attributes.initialize(sets, data.vitals)
	attributes.configure_progression(data.progression, data.initial_level)
	for skill_id in data.ability_ids:
		abilities.learn_ability(session.catalog.instantiate_definition("skills", skill_id) as GameplayAbilityDefinition)
	return [attributes, abilities, statuses]

static func cleanup(abilities: GameplayAbilityComponent, statuses: GameplayStatusComponent) -> void:
	if statuses != null:
		for status in statuses.get_active_statuses():
			statuses.remove_status(status.status_data.status_id)
	if abilities != null:
		for id in abilities.get_all_ability_ids():
			var instance := abilities.get_ability_instance(id)
			instance.end_ability()
			abilities.forget_ability(id)
			instance.clear_blackboard()
#endregion
