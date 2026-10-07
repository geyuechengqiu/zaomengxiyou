extends Resource
class_name GameplayVital
#region 上限变化策略
enum MaxChangePolicy { KEEP_CURRENT, KEEP_RATIO, FILL, ADD_DELTA }
var max_change_policy: MaxChangePolicy = MaxChangePolicy.KEEP_CURRENT
#endregion
#region 配置与运行状态

## 属性状态

## Vital 配置字段
@export_group("Identity")
@export var vital_id: StringName = &""  ## Vital ID（唯一标识）
@export var display_name: String = ""   ## 显示名称

@export_group("Attribute Dependencies")
## 决定最大值的属性 ID (如 "hpMax", "mpMax")
@export var max_value_attribute: StringName = &""
## 决定恢复速度的属性 ID (如 "reHP", "reMP")，留空则不自动恢复
@export var regen_rate_attribute: StringName = &""

# --- 运行时数据 ---
var _owner_comp: GameplayAttributeComponent  ## 属性组件引用
var current_value: float = 0.0  				## 当前值
var _cached_max: float = 0.0     			## 缓存的最大值
#endregion
#region 信号

# --- 信号 ---
signal value_changed(current: float, max: float, percent: float, is_regen: bool)
signal depleted()  # 归零
signal full()      # 满值
#endregion
#region 公共接口

# --- 逻辑 ---
## 初始化 Vital 实例
## 绑定到指定的属性组件并初始化数值
## [param] p_comp: GameplayAttributeComponent 属性组件引用
func initialize(p_comp: GameplayAttributeComponent) -> void:
	_owner_comp = p_comp
	# 初始化数值（必须在设置 _owner_comp 之后）
	_update_cached_max()
	current_value = _cached_max
	# 连接属性变化信号（确保 Vital 能响应属性变化）
	if is_instance_valid(_owner_comp):
		if _owner_comp.attribute_value_changed.is_connected(_on_attribute_changed):
			_owner_comp.attribute_value_changed.disconnect(_on_attribute_changed)
		_owner_comp.attribute_value_changed.connect(_on_attribute_changed)

func create_instance(p_comp: GameplayAttributeComponent) -> GameplayVital:
	var instance : GameplayVital = duplicate(true)
	instance.initialize(p_comp)
	return instance

## 处理恢复
func process_regen(delta: float):
	if regen_rate_attribute == &"": return
	
	var rate = _owner_comp.get_value(regen_rate_attribute)
	if rate != 0:
		modify_value(rate * delta, true)

## 修改值
## [param] amount: float 修改量（正数为增加，负数为减少）
## [param] is_regen: bool 是否为自动回复（默认 false）
## 注意：depleted 和 full 信号始终会发射（如果条件满足）
func modify_value(amount: float, is_regen: bool = false) -> void:
	_modify_value(amount, is_regen)

## 获取最大值
## [return] float 当前的最大值
func get_max_value() -> float:
	return _cached_max

## 获取百分比
## [return] float 百分比（0.0-1.0）
func get_percent() -> float:
	return current_value / _cached_max if _cached_max > 0 else 0.0

func set_current_value(value: float) -> void:
	_modify_value(value - current_value)
#endregion
#region 内部实现

## 更新缓存的最大值
func _update_cached_max() -> void:
	if not is_instance_valid(_owner_comp):
		push_error("Vital: _owner component is not valid!")
		return
	var old_max = _cached_max
	_cached_max = _owner_comp.get_value(max_value_attribute)
	if old_max != _cached_max:
		value_changed.emit(current_value, _cached_max, get_percent(), false)

func _modify_value(amount: float, is_regen: bool = false) -> void:
	_update_cached_max()
	var old_val = current_value
	current_value = clampf(current_value + amount, 0.0, _cached_max)
	
	if old_val == current_value: return

	value_changed.emit(current_value, _cached_max, get_percent(), is_regen)
	
	if current_value <= 0 and old_val > 0:
		depleted.emit()
	elif current_value >= _cached_max and old_val < _cached_max:
		full.emit()
#endregion
#region 信号回调

## 属性变化回调
## [param] attr_id: StringName 变化的属性ID
## [param] val: float 新值
func _on_attribute_changed(attr_id: StringName, _val: float) -> void:
	if attr_id != max_value_attribute: return
	var previous_max := _cached_max
	var previous_value := current_value
	_cached_max = maxf(0.0, _owner_comp.get_value(max_value_attribute))
	match max_change_policy:
		MaxChangePolicy.KEEP_RATIO:
			current_value = previous_value / previous_max * _cached_max if previous_max > 0.0 else 0.0
		MaxChangePolicy.FILL:
			current_value = _cached_max
		MaxChangePolicy.ADD_DELTA:
			current_value += _cached_max - previous_max
	current_value = clampf(current_value, 0.0, _cached_max)
	value_changed.emit(current_value, _cached_max, get_percent(), false)
	if current_value <= 0.0 and previous_value > 0.0:
		depleted.emit()
#endregion
