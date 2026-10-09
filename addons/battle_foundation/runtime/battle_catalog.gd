extends RefCounted
class_name BattleCatalog
#region 索引与校验状态
const CATEGORIES := ["characters", "skills", "monsters", "equipment", "levels", "statuses"]
var last_error: String = ""
var _definitions: Dictionary = {}
var _paths: Dictionary = {}
#endregion
#region 公共接口
## JSON 仅作 ID -> .tres 索引。先完整校验再替换，加载失败保留上一份有效索引。
func load_manifest(path: String) -> bool:
	last_error = ""
	if not FileAccess.file_exists(path):
		return _fail("索引文件不存在：" + path)
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return _fail("索引 JSON 无效：" + parser.get_error_message())
	if not parser.data is Dictionary:
		return _fail("索引根节点必须是 Dictionary")
	var document: Dictionary = parser.data
	if document.get("version") != 1 or not document.get("definitions") is Dictionary:
		return _fail("需要 version=1 与 definitions")
	var next_definitions := {}
	var next_paths := {}
	for category in document.definitions:
		if not CATEGORIES.has(category):
			return _fail("未知定义类别：" + str(category))
	for category in CATEGORIES:
		var entries: Variant = document.definitions.get(category, {})
		if not entries is Dictionary:
			return _fail("类别必须是 ID/路径字典：" + category)
		next_definitions[category] = {}
		next_paths[category] = {}
		for id in entries:
			if not id is String or id.is_empty():
				return _fail("定义 ID 不能为空")
			var resource_path: Variant = entries[id]
			if not resource_path is String or not resource_path.begins_with("res://"):
				return _fail("定义必须使用 res:// 资源路径：" + id)
			if not ResourceLoader.exists(resource_path):
				return _fail("资源不存在：" + resource_path)
			var definition := CoreSystem.resource_manager.load_resource(resource_path)
			if not _validate_definition(category, id, definition):
				return false
			next_definitions[category][StringName(id)] = definition
			next_paths[category][StringName(id)] = resource_path
	if not _validate_references(next_definitions):
		return false
	_definitions = next_definitions
	_paths = next_paths
	return true

func has_definition(category: String, id: StringName) -> bool:
	return _definitions.get(category, {}).has(id)

## 调用方只能取得独立资源图；外部 .tres 子资源也复制，避免修改 Core 缓存。
func instantiate_definition(category: String, id: StringName) -> Resource:
	var definition: Resource = _definitions.get(category, {}).get(id)
	if definition == null:
		last_error = "定义不存在：%s/%s" % [category, id]
		return null
	return definition.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)

func get_resource_path(category: String, id: StringName) -> String:
	return _paths.get(category, {}).get(id, "")

func get_ids(category: String) -> Array:
	return _definitions.get(category, {}).keys().duplicate()
#endregion
#region 校验实现
func _validate_definition(category: String, id: String, data: Resource) -> bool:
	var resource_id: StringName
	match category:
		"characters", "monsters":
			if not data is BattleEntityDefinition:
				return _fail("实体定义类型错误：" + id)
			resource_id = data.definition_id
			if data.attribute_set == null:
				return _fail("实体缺少属性集：" + id)
			var attributes := {}
			for attribute: GameplayAttribute in data.attribute_set.attributes:
				if attribute == null or attribute.attribute_id.is_empty() or attributes.has(attribute.attribute_id):
					return _fail("实体属性 ID 无效或重复：" + id)
				var value: float = data.attribute_set.attributes[attribute]
				if not is_finite(value):
					return _fail("实体属性值必须有限：" + id)
				attributes[attribute.attribute_id] = true
			if data.progression != null:
				if data.progression.attribute_set == null or not data.progression.is_configuration_valid(attributes):
					return _fail("成长/经验配置无效：" + id)
				if data.initial_level < 1 or data.initial_level > data.progression.maximum_level:
					return _fail("初始等级超出成长范围：" + id)
				for attribute: GameplayAttribute in data.progression.attribute_set.attributes:
					if attribute == null or attribute.attribute_id.is_empty() or attributes.has(attribute.attribute_id):
						return _fail("成长属性 ID 无效或重复：" + id)
					attributes[attribute.attribute_id] = true
				if not attributes.has(&"level") or not attributes.has(&"exp"):
					return _fail("成长属性集必须包含 level / exp：" + id)
			var vital_ids := {}
			for vital: GameplayVital in data.vitals:
				if vital == null or vital.vital_id.is_empty() or vital_ids.has(vital.vital_id):
					return _fail("实体 Vital ID 无效或重复：" + id)
				if not attributes.has(vital.max_value_attribute):
					return _fail("Vital 上限属性不存在：" + id)
				if not vital.regen_rate_attribute.is_empty() and not attributes.has(vital.regen_rate_attribute):
					return _fail("Vital 恢复属性不存在：" + id)
				vital_ids[vital.vital_id] = true
		"skills":
			if not data is GameplayAbilityDefinition:
				return _fail("技能应使用 GAS 定义：" + id)
			resource_id = data.ability_id
			var feature_names := {}
			for feature: GameplayAbilityFeature in data.features:
				if feature == null or feature_names.has(feature.feature_name):
					return _fail("技能 Feature 无效或重复：" + id)
				feature_names[feature.feature_name] = true
				if feature is BattleSkillCooldownFeature and not BattleSkillLevelValues.is_valid(feature.durations):
					return _fail("技能等级冷却配置无效：" + id)
				if feature is CostFeature:
					for cost in feature.costs:
						if cost is BattleSkillManaCost and (cost.skill_id != data.ability_id or not BattleSkillLevelValues.is_valid(cost.amounts)):
							return _fail("技能等级消耗配置无效：" + id)
				if feature is BattleFrameTimelineFeature and not feature.is_configuration_valid():
					return _fail("技能素材帧事件配置无效：" + id)
				if feature is BattleFrameTimelineFeature and feature.commit_resources and data.execution_tree != null:
					return _fail("技能消耗/冷却只能由时间轴或行为树一方提交：" + id)
		"statuses":
			if not data is GameplayStatusData:
				return _fail("状态应使用 GAS 定义：" + id)
			resource_id = data.status_id
			if not is_finite(data.duration) or data.duration < -1.0 or data.max_stacks < 1 or not is_finite(data.initial_update_delta) or data.initial_update_delta < 0.0:
				return _fail("状态持续时间/层数/初始推进无效：" + id)
			for feature in data.features:
				if feature == null:
					return _fail("状态 Feature 无效：" + id)
				if feature is FeaturePeriodicEffects and (not is_finite(feature.period) or feature.period <= 0.0):
					return _fail("状态周期无效：" + id)
				if feature is BattleTriggerFeature and (not is_finite(feature.cooldown) or feature.cooldown < 0.0 or not is_finite(feature.chance) or feature.chance < 0.0 or feature.chance > 1.0 or not is_finite(feature.health_threshold) or feature.health_threshold < 0.0 or feature.health_threshold > 1.0):
					return _fail("战斗触发条件无效：" + id)
		"equipment":
			if not data is BattleEquipmentDefinition:
				return _fail("装备定义类型错误：" + id)
			resource_id = data.definition_id
			if not is_finite(data.max_durability) or data.max_durability < 0.0:
				return _fail("装备耐久值无效：" + id)
		"levels":
			if not data is BattleLevelDefinition:
				return _fail("关卡定义类型错误：" + id)
			if not data.get_progression_error().is_empty(): return _fail(data.get_progression_error())
			resource_id = data.definition_id
	if resource_id != StringName(id):
		return _fail("索引 ID 与资源定义 ID 不一致：" + id)
	return true

func _validate_references(definitions: Dictionary) -> bool:
	for skill: GameplayAbilityDefinition in definitions.skills.values():
		for feature in skill.features:
			if not feature is BattleFrameTimelineFeature:
				continue
			for status_id in feature.initial_status_ids:
				if not definitions.statuses.has(status_id):
					return _fail("技能引用了未登记起手状态：" + String(status_id))
			for branch in feature.branch_windows:
				if not definitions.skills.has(branch.target_ability_id):
					return _fail("派生引用了未登记技能：" + String(branch.target_ability_id))
			for segment in feature.attack_segments:
				if not segment.sub_skill_id.is_empty() and not definitions.skills.has(segment.sub_skill_id):
					return _fail("攻击段引用了未登记子技能：" + String(segment.sub_skill_id))
				for status_id in segment.status_ids:
					if not definitions.statuses.has(status_id):
						return _fail("攻击段引用了未登记状态：" + String(status_id))
	for category in ["characters", "monsters"]:
		for entity: BattleEntityDefinition in definitions[category].values():
			for skill_id in entity.ability_ids:
				if not definitions.skills.has(skill_id):
					return _fail("实体引用了未登记技能：" + String(skill_id))
			for status_id in entity.initial_status_ids:
				if not definitions.statuses.has(status_id):
					return _fail("实体引用了未登记状态：" + String(status_id))
	for level: BattleLevelDefinition in definitions.levels.values():
		for plan in level.spawn_plans:
			for monster_id in plan.monster_ids:
				if not definitions.monsters.has(monster_id): return _fail("出生计划引用了未登记怪物：" + String(monster_id))
		for spawn: BattleSpawnDefinition in level.spawns:
			if spawn == null or not ["characters", "monsters"].has(spawn.category):
				return _fail("关卡出生定义类型错误")
			if not definitions[spawn.category].has(spawn.entity_definition_id):
				return _fail("关卡引用了未登记实体：" + String(spawn.entity_definition_id))
	return true

func _fail(message: String) -> bool:
	last_error = message
	return false
#endregion
