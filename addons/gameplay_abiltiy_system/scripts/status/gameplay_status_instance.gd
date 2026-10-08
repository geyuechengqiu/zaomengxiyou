extends RefCounted
class_name GameplayStatusInstance
#region 配置与运行状态

## 状态实例
## 管理一个状态的生命周期，包括持续时间、层数、效果执行等

var status_data: GameplayStatusData
var owner_component: GameplayStatusComponent  ## 状态组件
var _instigator_ref: WeakRef
var instigator: Node:
	get: return _instigator_ref.get_ref() as Node if _instigator_ref != null else null
var removed: bool = false
var elapsed: float = 0.0
var stacks: int = 1
## 被动技能的所有权分组，避免遗忘一个技能误移除其它来源。
var owner_source_id: StringName = &""

# 计时管理（由组件统一管理，这里只存储剩余时间）
var remaining_duration: float = -1.0  ## 剩余持续时间，-1 表示永久，0 表示已过期
var _duration_policy: StatusDurationPolicy = null

# 上下文缓存（用于移除时效果和周期性效果）
var _cached_context: Dictionary = {}  ## 保存应用时的上下文（用于周期性效果和移除时效果）
var _cue_instance: GameplayCue = null  ## 保存克隆的 Cue 实例（用于停止时清理）

var _feature_storage: Dictionary = {}  # 存储 Feature 的运行时数据
#endregion
#region 信号

## 状态完成信号（瞬时状态立即完成，持续状态在移除时完成）发出此信号
signal status_completed(status_instance: GameplayStatusInstance)
#endregion
#region 生命周期与引擎回调

func _init(gsd: GameplayStatusData, p_owner_component: GameplayStatusComponent, p_instigator: Node, p_stacks: int) -> void:
	status_data = gsd
	owner_component = p_owner_component
	_instigator_ref = weakref(p_instigator) if is_instance_valid(p_instigator) else null
	stacks = p_stacks
#endregion
#region 公共接口
	
## 状态被施加时，应用所有效果
func apply(context: Dictionary = {}) -> void:
	# 保存上下文（用于周期性效果和移除时效果）
	_cached_context = context.duplicate()
	_cached_context["effect_state"] = {}
	if status_data.duration != 0.0:
		if is_instance_valid(status_data.duration_policy):
			_duration_policy = status_data.duration_policy.duplicate()
			_duration_policy.initialize(self, status_data.duration)
		_remove_mutually_exclusive_statuses()
		_apply_status_tags()

	# 在 context 中添加 source_id（用于效果系统识别来源）
	if not context.has("source_id"):
		context["source_id"] = _get_source_instance_id()

	# 应用应用时效果
	_apply_effects(status_data.apply_effects, context)

	# 应用所有的feature
	for feature in status_data.features:
		if removed:
			return
		if is_instance_valid(feature):
			feature.apply_feature(self, context)

	# 如果是瞬时状态（duration = 0），立即移除并发出完成信号
	if status_data.duration == 0.0:
		status_completed.emit(self)
		return

	# 执行状态 Cue（视觉反馈）
	_execute_status_cue()
	if status_data.initial_update_delta > 0.0 and update(status_data.initial_update_delta):
		owner_component.remove_instance(self, &"expired")

## 状态被移除时，移除所有效果
func remove(reason: StringName = &"removed") -> void:
	if removed:
		return
	removed = true
	_cached_context["remove_reason"] = reason
	# 1. 应用移除时效果（用于其他清理逻辑，如视觉效果、事件触发等）
	var remove_context = _cached_context.duplicate()
	remove_context["stacks"] = stacks
	# 确保 source_id 存在（用于效果系统识别来源）
	remove_context["source_id"] = _get_source_instance_id()
	_apply_effects(status_data.remove_effects, remove_context)
	_remove_effects(status_data.apply_effects, remove_context)

	# 移除所有 Feature
	for feature in status_data.features:
		if is_instance_valid(feature):
			feature.remove_feature(self, remove_context)

	# 清理 Feature 存储
	_feature_storage.clear()
	
	# 2. 移除状态标签（标签系统集成）
	_remove_status_tags()

	# 3. 停止状态 Cue（清理视觉反馈）
	_stop_status_cue()

	# 4. 发出完成信号（持续状态在移除时完成）
	status_completed.emit(self)
	_cached_context.clear()
	owner_component = null
	_instigator_ref = null

## 更新状态（由组件在 _process 中调用）
## [param] delta: float 帧时间
## [return] bool 是否已过期（需要移除）
func update(delta: float) -> bool:
	if removed:
		return true
	var active_delta := minf(delta, maxf(0.0, remaining_duration)) if _duration_policy != null and status_data.duration > 0.0 else delta
	elapsed += active_delta
	# 先执行截至到期点的周期事件，再过期；低帧率不漏最后一次周期。
	for feature in status_data.features:
		if removed:
			return true
		if is_instance_valid(feature):
			feature.update_feature(self, active_delta)
	return removed or (_duration_policy != null and _duration_policy.update(self, delta))

## 增加层数
## 在一个属性事务中撤销旧层效果，再按新层数应用，避免残留与中间状态通知。
func add_stack(amount: int = 1, is_refresh_duration: bool = true) -> void:
	if removed or amount <= 0:
		return
	var next := mini(stacks + amount, status_data.max_stacks)
	if next != stacks:
		var attributes := _get_attribute_component()
		if attributes != null:
			attributes.begin_update()
		var context := _cached_context.duplicate()
		context["source_id"] = _get_source_instance_id()
		_refresh_stack_effects(status_data.apply_effects, context, false)
		stacks = next
		context["stacks"] = stacks
		_refresh_stack_effects(status_data.apply_effects, context, true)
		if attributes != null:
			attributes.end_update()
	if is_refresh_duration:
		refresh_duration()

func _refresh_stack_effects(effects: Array[GameplayEffect], context: Dictionary, applying: bool) -> void:
	for effect in effects:
		if effect.reapply_on_stack:
			if applying:
				_apply_effects([effect], context)
			else:
				_remove_effects([effect], context)
		else:
			_refresh_stack_effects(effect.sub_effects, context, applying)

## 处理事件（用于事件监听型效果）
## 此方法用于处理通过统一事件系统触发的事件
func handle_event(event_id: StringName, context: Dictionary) -> void:
	# 检查状态是否应该响应这个事件
	if removed or not status_data.can_trigger_on_event(event_id):
		return

	# 调用持续时间策略的handle_event方法
	if is_instance_valid(_duration_policy):
		_duration_policy.handle_event(self, event_id, context)

	# 让所有 Feature 处理事件
	for feature in status_data.features:
		if removed:
			return
		if is_instance_valid(feature):
			feature.handle_event(self, event_id, context)

## 刷新持续时间
func refresh_duration() -> void:
	if is_instance_valid(_duration_policy) and status_data.duration > 0:
		elapsed = 0.0
		_duration_policy.refresh(self, status_data.duration)

## 累加持续时间
func accumulate_duration(amount: float = -1.0) -> void:
	if is_instance_valid(_duration_policy) and status_data.duration > 0:
		_duration_policy.accumulate(self, amount if amount >= 0.0 else status_data.duration)

## 应用方法（公开）
func apply_effects(effects: Array[GameplayEffect], context: Dictionary = {}) -> void:
	_apply_effects(effects, context)

func apply_effects_to(effects: Array[GameplayEffect], target: Node, source: Node, context: Dictionary = {}) -> void:
	_apply_effects(effects, context, target, source)

## 获取特性数据
func get_feature_storage(feature: StatusFeature) -> Dictionary:
	if not _feature_storage.has(feature):
		_feature_storage[feature] = {}
	return _feature_storage[feature]

func has_event_listening() -> bool:
	if is_instance_valid(status_data):
		return status_data.has_event_listening()
	return false
#endregion
#region 内部实现

## 应用效果
func _apply_effects(effects: Array[GameplayEffect], context: Dictionary = {}, recipient: Node = null, source: Node = null) -> void:
	if not is_instance_valid(owner_component):
		return

	var target: Node = recipient if recipient != null else owner_component.get_parent()
	if not is_instance_valid(target):
		return
	
	var execution_context := _cached_context.duplicate()
	execution_context.merge(context, true)
	execution_context["stacks"] = stacks
	execution_context["source_id"] = _get_source_instance_id()
	execution_context["effect_state"] = _cached_context["effect_state"]
	var attributes := _get_attribute_component()
	if attributes != null:
		attributes.begin_update()

	# 应用所有的果
	for effect_template in effects:
		if removed and not context.has("remove_reason"):
			break
		if not is_instance_valid(effect_template):
			continue
		
		# 克隆效果实例（避免状态共享）
		var effect_clone = effect_template.duplicate(true) as GameplayEffect
		if not is_instance_valid(effect_clone):
			continue
		
		# 应用效果（瞬时操作，不存储）
		effect_clone.apply(target, source if source != null else instigator, execution_context)
	if attributes != null:
		attributes.end_update()

## 移除效果
func _remove_effects(effects: Array[GameplayEffect], context: Dictionary) -> void:
	if not is_instance_valid(owner_component):
		return

	var target = owner_component.get_parent()
	if not is_instance_valid(target):
		return
	
	# 在context中添加实例来源和层数
	context["source_id"] = _get_source_instance_id()
	context["stacks"] = stacks
	var attributes := _get_attribute_component()
	if attributes != null:
		attributes.begin_update()

	# 应用所有的果
	for effect_template in effects:
		if not is_instance_valid(effect_template):
			continue
		
		# 克隆效果实例（避免状态共享）
		var effect_clone = effect_template.duplicate(true) as GameplayEffect
		if not is_instance_valid(effect_clone):
			continue
		
		# 应用效果（瞬时操作，不存储）
		effect_clone.remove(target, instigator, context)
	if attributes != null:
		attributes.end_update()

func _get_attribute_component() -> GameplayAttributeComponent:
	if not is_instance_valid(owner_component):
		return null
	return GameplayAbilitySystem.get_component_by_interface(owner_component.get_parent(), &"GameplayVitalAttributeComponent") as GameplayAttributeComponent

## 应用状态标签（标签系统集成）
func _apply_status_tags() -> void:
	if not is_instance_valid(owner_component) or not is_instance_valid(status_data):
		return

	# 应用状态的所有标签
	for tag_id in status_data.tags:
		if tag_id != &"":
			TagManager.add_tag(owner_component.get_parent(), tag_id)

## 移除状态标签（标签系统集成）
func _remove_status_tags() -> void:
	if not is_instance_valid(owner_component) or not is_instance_valid(status_data):
		return
		
	# 移除状态的所有标签
	for tag_id in status_data.tags:
		if tag_id != &"":
			TagManager.remove_tag(owner_component.get_parent(), tag_id)

## 移除互斥状态（状态系统层面的互斥处理）
func _remove_mutually_exclusive_statuses() -> void:
	if not is_instance_valid(owner_component) or not is_instance_valid(status_data):
		return

	var target = owner_component.get_parent()
	if not is_instance_valid(target):
		return

	# 获取当前状态的所有标签的互斥标签
	var tags_to_remove: Array[StringName] = []
	for tag_id in status_data.tags:
		if tag_id == &"":
			continue
		# 获取该标签的所有互斥标签
		var exclusions = TagManager.get_tag_exclusions(tag_id)
		tags_to_remove.append_array(exclusions)

	# 移除所有带互斥标签的状态
	if not tags_to_remove.is_empty():
		owner_component.remove_statuses_by_tags(tags_to_remove)

## 执行状态 Cue（视觉反馈）
func _execute_status_cue() -> void:
	if not is_instance_valid(owner_component) or not is_instance_valid(status_data):
		return
		
	if not is_instance_valid(status_data.cue):
		return
	
	# 【关键】克隆 Cue 实例（避免直接修改配置数据）
	# 使用 deep 复制，确保所有 Cue 组件也被克隆
	_cue_instance = status_data.cue.duplicate(true) as GameplayCue
	if not is_instance_valid(_cue_instance):
		push_warning("GameplayStatusInstance: Failed to duplicate cue instance")
		return
		
	# 执行克隆的 Cue 实例（Manager 会处理挂点计算）
	GameplayCueManager.execute_cue(_cue_instance, owner_component.get_parent(), {})
	
## 停止状态 Cue（清理视觉反馈）
func _stop_status_cue() -> void:
	if not is_instance_valid(_cue_instance):
		# 如果没有保存的 Cue 实例，说明可能没有执行过 Cue，直接返回
		return
		
	# 停止克隆的 Cue 实例（Manager 会处理挂点计算）
	GameplayCueManager.stop_cue(_cue_instance, owner_component.get_parent(), {})

func _get_source_instance_id() -> StringName:
	return "status." + str(get_instance_id())
#endregion
