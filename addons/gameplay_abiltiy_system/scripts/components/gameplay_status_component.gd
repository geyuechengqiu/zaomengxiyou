extends Node
class_name GameplayStatusComponent
#region 配置与运行状态

## 状态组件
## 管理实体的所有状态（Buff/Debuff）

var _active_statuses: Dictionary[StringName, GameplayStatusInstance] = {}
var _has_event_listening_statuses: bool = false  # 是否有需要监听事件的状态
var _event_bus: Node
@export var externally_driven: bool = false
## 战斗宿主可提供 accepts_status_event()，默认独立 GAS 保持全局广播行为。
@export var filter_events_by_owner: bool = false
#endregion
#region 信号

signal status_applied(status_id: StringName, instance: GameplayStatusInstance)
signal status_removed(status_id: StringName)
signal status_stacked(status_id: StringName, new_stacks: int)
#endregion
#region 生命周期与引擎回调

func _enter_tree() -> void:
	# Core 的统一推送信号保留任意自定义事件，不依赖固定的事件名列表。
	_event_bus = CoreSystem.event_bus
	if not is_instance_valid(_event_bus):
		push_error("GameplayStatusComponent requires CoreSystem.event_bus.")
		return
	if not _event_bus.event_pushed.is_connected(_on_core_event_pushed):
		_event_bus.event_pushed.connect(_on_core_event_pushed)

func _exit_tree() -> void:
	if is_instance_valid(_event_bus) and _event_bus.event_pushed.is_connected(_on_core_event_pushed):
		_event_bus.event_pushed.disconnect(_on_core_event_pushed)
	_event_bus = null

func _process(delta: float) -> void:
	if not externally_driven:
		advance_simulation(delta)

func advance_simulation(delta: float) -> void:
	if delta <= 0.0:
		return
	# 统一更新所有状态的计时器
	var statuses_to_remove: Array[StringName] = []

	for status_id in _active_statuses.keys():
		var instance = _active_statuses.get(status_id)
		if not is_instance_valid(instance):
			statuses_to_remove.append(status_id)
			continue
		# 调用状态的 update 方法
		var should_remove = instance.update(delta)
		if should_remove:
			statuses_to_remove.append(status_id)

	# 移除已过期的状态
	for status_id in statuses_to_remove:
		remove_status(status_id)
#endregion
#region 公共接口

func apply_status(gsd: GameplayStatusData, instigator: Node, stacks: int = 1, context: Dictionary = {}) -> GameplayStatusInstance:
	if not is_instance_valid(gsd):
		push_error("GameplayStatusComponent: GameplayStatusData is not valid!")
		return null
	
	var status_id: StringName = gsd.status_id
	# 空 ID：仅执行一次性效果，不入表
	if status_id.is_empty():
		return _create_and_apply_new_status_instance(gsd, instigator, stacks, context)

	# 1. 优先级检查
	if not _handle_priority_for_existing_status(status_id, gsd):
		return null

	# 2. 堆叠策略
	if _apply_stacking_for_existing_status(status_id, gsd, stacks):
		return null

	# 3. 创建并应用新实例
	return _create_and_apply_new_status_instance(gsd, instigator, stacks, context)

func remove_status(status_id: StringName) -> void:
	var instance = _active_statuses.get(status_id)
	if not is_instance_valid(instance): 
		return
		
	_active_statuses.erase(status_id)
	instance.remove()
	status_removed.emit(status_id)

	# 检查是否还有需要监听事件的状态
	_update_event_listening_status()

	# 触发统一游戏事件：status_removed
	CoreSystem.event_bus.push_event("status_removed", [{
		"entity": get_parent(),
		"status_id": status_id
	}], true)
	
func remove_statuses_by_tags(tags_to_remove: Array[StringName]) -> void:
	for status_id in _active_statuses.keys():
		var instance = _active_statuses.get(status_id)
		if not is_instance_valid(instance): 
			continue
		var gsd = instance.status_data
		# 检查这个Status的tags是否与我们要移除的tags有交集
		for tag in gsd.tags:
			if tags_to_remove.has(tag):
				# 找到了一个匹配！移除这个Status
				remove_status(status_id)
				break  # 移动到下一个状态实例

## 获取所有激活的状态
func get_active_statuses() -> Array[GameplayStatusInstance]:
	return _active_statuses.values()

## 获取指定状态
func get_status(status_id: StringName) -> GameplayStatusInstance:
	return _active_statuses.get(status_id, null)

## 检查是否有指定状态
func has_status(status_id: StringName) -> bool:
	return _active_statuses.has(status_id)

## 获取随机状态
## [param] is_debuff: bool 是否只获取Debuff
func get_random_status(is_debuff: bool = false, debuff_tag : String = "status.debuff") -> GameplayStatusInstance:
	if _active_statuses.size() == 0:
		return null

	var statuses: Array[GameplayStatusInstance] = []
	for status in _active_statuses.values():
		if not is_debuff or status.status_data.tags.has(debuff_tag):
			statuses.append(status)

	if statuses.size() == 0:
		return null

	if get_parent().has_method("get_battle_random_int"):
		return statuses[get_parent().get_battle_random_int(0, statuses.size() - 1, &"combat")]
	return statuses.pick_random()

## 处理事件（供外部调用，触发事件监听型效果）
func handle_event(event_id: StringName, context: Dictionary) -> void:
	# 只处理有事件监听需求的状态
	if not _has_event_listening_statuses:
		return
		
	for instance in _active_statuses.values():
		if is_instance_valid(instance):
			instance.handle_event(event_id, context)
#endregion
#region 内部实现

func _apply_stacking_for_existing_status(status_id: StringName, gsd: GameplayStatusData, stacks: int) -> bool:
	if not _active_statuses.has(status_id):
		return false

	var existing_instance: GameplayStatusInstance = _active_statuses[status_id]
	if not is_instance_valid(existing_instance):
		_active_statuses.erase(status_id)
		return false
	
	# 使用策略模式处理堆叠
	if is_instance_valid(gsd) and is_instance_valid(gsd.stacking_policy):
		var context = {}
		return gsd.stacking_policy.handle_stacking(existing_instance, gsd, stacks, context)

	return true

func _handle_priority_for_existing_status(status_id: StringName, gsd: GameplayStatusData) -> bool:
	if not _active_statuses.has(status_id):
		return true
	var existing_instance: GameplayStatusInstance = _active_statuses[status_id]
	if not is_instance_valid(existing_instance) or not is_instance_valid(existing_instance.status_data):
		_active_statuses.erase(status_id)
		return true

	var existing_priority: int = existing_instance.status_data.priority
	if gsd.priority > existing_priority:
		remove_status(status_id)
		return true
	elif gsd.priority < existing_priority:
		return false

	return true

## 创建并应用新的状态实例
## - 对于有 ID 的状态：根据 duration 决定是否写入 _active_statuses
## - 对于 ID 为空的状态：不会写入 _active_statuses，仅执行一次性效果
func _create_and_apply_new_status_instance(gsd: GameplayStatusData, instigator: Node, stacks: int, context: Dictionary) -> GameplayStatusInstance:
	var instance := GameplayStatusInstance.new(gsd, self, instigator, stacks)
	var status_id: StringName = gsd.status_id
	
	# 检查是否需要监听事件
	if gsd.has_event_listening():
		_has_event_listening_statuses = true

	# 仅当状态 ID 非空且有持续时间时才记录到激活状态表
	if not status_id.is_empty() and gsd.duration != 0.0:
		_active_statuses[status_id] = instance

	# 先应用状态（执行效果）
	instance.apply(context)
	
	# 发信号和事件（即便 ID 为空，也允许外部根据实例做自定义逻辑）
	status_applied.emit(status_id, instance)

	# 触发统一游戏事件：status_applied
	CoreSystem.event_bus.push_event("status_applied", [{
		"entity": get_parent(),
		"status_id": status_id
	}], true)
	
	return instance

## 更新事件监听状态（检查是否还有需要监听事件的状态）
func _update_event_listening_status() -> void:
	_has_event_listening_statuses = false
	for instance : GameplayStatusInstance in _active_statuses.values():
		if is_instance_valid(instance) and is_instance_valid(instance.status_data):
			if instance.has_event_listening():
				_has_event_listening_statuses = true
				break
#endregion
#region 信号回调

func _on_core_event_pushed(event_type: String, payload: Array) -> void:
	# Core 按 Array 拆分回调参数；GAS 事件固定携带一个原始 Dictionary。
	# 忽略其它 Core 事件的负载形状，避免基础服务事件进入战斗状态。
	if payload.size() != 1 or not payload[0] is Dictionary:
		return
	if filter_events_by_owner and get_parent().has_method("accepts_status_event"):
		if not get_parent().accepts_status_event(payload[0]):
			return
	handle_event(StringName(event_type), payload[0])
	
#endregion
