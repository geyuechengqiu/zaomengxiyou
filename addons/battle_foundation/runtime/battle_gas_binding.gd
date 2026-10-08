extends RefCounted
class_name BattleGASBinding
#region 共用 GAS 场景绑定
## 2D/3D 实体共享绑定入口；组件必须预置，Vital 和技能黑板仍各实例独占。
static func get_configuration_error(owner: Node, data: BattleEntityDefinition = null) -> String:
	for spec in [[^"GameplayVitalAttributeComponent", BattleAttributeComponent], [^"GameplayAbilityComponent", GameplayAbilityComponent], [^"GameplayStatusComponent", GameplayStatusComponent], [^"DamageRules", BattleDamageRulesComponent]]:
		if not is_instance_of(owner.get_node_or_null(spec[0]), spec[1]):
			return "实体场景缺少或类型错误的预置组件：" + str(spec[0])
	return (owner.get_node(^"GameplayVitalAttributeComponent") as BattleAttributeComponent).get_initial_configuration_error(data) if data != null else ""

static func attach(owner: Node, session: BattleSession, data: BattleEntityDefinition) -> Array:
	assert(get_configuration_error(owner, data).is_empty(), get_configuration_error(owner, data))
	var attributes := owner.get_node_or_null(^"GameplayVitalAttributeComponent") as BattleAttributeComponent
	var abilities := owner.get_node_or_null(^"GameplayAbilityComponent") as GameplayAbilityComponent
	var statuses := owner.get_node_or_null(^"GameplayStatusComponent") as GameplayStatusComponent
	attributes.externally_driven = true
	abilities.externally_driven = true
	statuses.externally_driven = true
	statuses.filter_events_by_owner = true
	owner.set("attributes", attributes)
	owner.set("abilities", abilities)
	owner.set("statuses", statuses)
	attributes.initialize_from_definition(data)
	for skill_id in data.ability_ids:
		abilities.learn_ability(session.catalog.instantiate_definition("skills", skill_id) as GameplayAbilityDefinition)
	return [attributes, abilities, statuses]

static func cleanup(abilities: GameplayAbilityComponent, statuses: GameplayStatusComponent) -> void:
	if statuses != null:
		statuses.clear_statuses(&"exit")
	if abilities != null:
		for id in abilities.get_all_ability_ids():
			var instance := abilities.get_ability_instance(id)
			instance.end_ability()
			abilities.forget_ability(id)
			instance.clear_blackboard()
#endregion
