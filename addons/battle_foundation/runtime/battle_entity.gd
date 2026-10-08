extends CharacterBody3D
class_name BattleEntity
#region 实体运行状态
var entity_id: StringName = &""
var definition_id: StringName = &""
var faction_id: StringName = &"neutral"
var session: BattleSession
var attributes: BattleAttributeComponent
var abilities: GameplayAbilityComponent
var statuses: GameplayStatusComponent
var _definition: BattleEntityDefinition
var _cleaned: bool = false
var damage_rules: BattleDamageRules
#endregion
#region 初始化
func get_component_configuration_error(data: BattleEntityDefinition = null) -> String:
	return BattleGASBinding.get_configuration_error(self, data)

## 每次 spawn 只能初始化一次；定义由 Catalog 创建为该实体独占的资源图。
func initialize_battle(owner_session: BattleSession, id: StringName, data: BattleEntityDefinition) -> void:
	assert(entity_id.is_empty(), "战斗实体不能重复初始化")
	assert(get_component_configuration_error(data).is_empty(), get_component_configuration_error(data))
	session = owner_session
	entity_id = id
	definition_id = data.definition_id
	faction_id = data.faction_id
	_definition = data
	damage_rules = (get_node(^"DamageRules") as BattleDamageRulesComponent).rules
	var components := BattleGASBinding.attach(self, session, data)
	attributes = components[0]
	abilities = components[1]
	statuses = components[2]
	attributes.vital_depleted.connect(_on_vital_depleted)
	for status_id in data.initial_status_ids:
		apply_status_definition(status_id, self)
#endregion
#region 战斗入口
func advance_simulation(delta: float) -> void:
	if delta <= 0.0 or not is_instance_valid(session):
		return
	## 位移与碰撞在固定物理 tick 中进行，用缩放后的位移，保留原始 velocity。
	if is_alive() and not TagManager.has_tag(self, &"state.stunned") and not velocity.is_zero_approx():
		move_and_collide(velocity * delta)
	abilities.advance_simulation(delta)
	statuses.advance_simulation(delta)
	attributes.advance_simulation(delta)

func try_activate_skill(id: StringName, context: Dictionary = {}) -> bool:
	if session.is_simulation_blocked() or not abilities.has_ability(id):
		return false
	if not abilities.can_activate_ability(id, context):
		return false
	return abilities.try_activate_ability(id, context)

func apply_status_definition(id: StringName, instigator: Node = null) -> GameplayStatusInstance:
	var data := session.catalog.instantiate_definition("statuses", id) as GameplayStatusData
	if data == null:
		return null
	return statuses.apply_status(data, instigator if instigator != null else self)

func publish_battle_event(event_id: StringName, payload: Dictionary = {}) -> void:
	session.publish_event(event_id, self, self, payload)

func get_battle_random_int(minimum: int, maximum: int, stream: StringName = &"combat") -> int:
	return session.random.random_int(minimum, maximum, stream)

func get_battle_random_float(stream: StringName = &"combat") -> float:
	return session.random.random_float(stream)

func get_damage_rules() -> BattleDamageRules:
	return damage_rules

func get_damage_strategy() -> DamageLogicStrategy:
	return session.damage_strategy if session != null else null

func accepts_status_event(context: Dictionary) -> bool:
	if context.has("battle_id") and context.battle_id != session.battle_id:
		return false
	if context.has("battle_id") and (context.get("source_entity_id", &"") == entity_id or context.get("target_entity_id", &"") == entity_id):
		return true
	if context.has("entity"):
		return context.entity == self
	if context.has("target_entity_id") and context.target_entity_id != &"":
		return context.target_entity_id == entity_id
	## 只有显式带本场 battle_id 的事件可广播给本场全部状态。
	return context.get("battle_id", &"") == session.battle_id

func get_gameplay_vital_attribute_component() -> GameplayVitalAttributeComponent:
	return attributes

func get_gameplay_ability_component() -> GameplayAbilityComponent:
	return abilities

func get_gameplay_status_component() -> GameplayStatusComponent:
	return statuses
#endregion
#region 清理
func cleanup_battle() -> void:
	if _cleaned:
		return
	_cleaned = true
	BattleGASBinding.cleanup(abilities, statuses)
	damage_rules.clear()

func _exit_tree() -> void:
	cleanup_battle()
#endregion

#region 共用状态与伤害结果入口
func is_alive() -> bool:
	return attributes != null and attributes.get_vital_value(&"health") > 0.0

func can_use_ability(_id: StringName, _context: Dictionary = {}) -> bool:
	return not _cleaned and is_alive() and not TagManager.has_tag(self, &"state.stunned")

func can_receive_status(data: GameplayStatusData) -> bool:
	return not _cleaned and is_alive() and not (data.tags.has(&"status.debuff") and TagManager.has_tag(self, &"state.invulnerable"))

func receive_damage_info(info: DamageInfo, _kind: StringName = &"normal", _priority: int = 60, context: Dictionary = {}) -> float:
	if session.is_simulation_blocked() or not is_alive():
		return 0.0
	if info.applied and info.single_use:
		return info.actual_hp_loss
	info.set_meta(&"reaction_deferred", true)
	if TagManager.has_tag(self, &"state.invulnerable") and not bool(context.get("bypass_damage_policy", false)):
		info.applied = true
		info.is_immune = true
		info.final_damage = 0.0
		info.normal_damage = 0.0
		info.true_damage = 0.0
		info.hp_before = attributes.get_vital_value(&"health")
		info.hp_after = info.hp_before
	else:
		(attributes.get_vital(&"health") as HealthVital).apply_damage(info, self)
	session.publish_damage_result(info, self, context)
	cleanup_death_statuses()
	return info.actual_hp_loss

func _on_vital_depleted(id: StringName) -> void:
	if id == &"health":
		for skill_id in abilities.get_all_ability_ids():
			abilities.get_ability_instance(skill_id).end_ability()
		publish_battle_event(&"battle.entity_died")
		call_deferred(&"cleanup_death_statuses")

func cleanup_death_statuses() -> void:
	if is_instance_valid(statuses) and not is_alive():
		statuses.clear_statuses(&"death")
#endregion
