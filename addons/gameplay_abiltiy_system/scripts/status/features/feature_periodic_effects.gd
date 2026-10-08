extends StatusFeature
class_name FeaturePeriodicEffects
#region 配置与运行状态

## 周期性效果特性
## 在指定周期触发效果

@export var period: float = 1.0  # 周期时间（秒）
@export var trigger_on_apply: bool = false
@export var periodic_effects: Array[GameplayEffect] = []
#endregion
#region 内部实现

func _apply_feature(instance: GameplayStatusInstance, context: Dictionary) -> void:
	_set_timer(instance, 0.0)
	if trigger_on_apply:
		instance.apply_effects(periodic_effects, {"status_periodic": true})

func _update_feature(instance: GameplayStatusInstance, delta: float) -> void:
	if not is_finite(period) or period <= 0.0 or periodic_effects.is_empty():
		return

	var timer = _get_timer(instance) + delta
	_set_timer(instance, timer)

	while timer + 0.000000001 >= period and not instance.removed:
		timer = maxf(0.0, timer - period)
		_set_timer(instance, timer)
		instance.apply_effects(periodic_effects, {"status_periodic": true})

## 获取计时器（从实例中读取）
func _get_timer(instance: GameplayStatusInstance) -> float:
	var feature_storage = instance.get_feature_storage(self)
	return feature_storage.get("timer", 0.0)

## 设置计时器（存储到实例中）
func _set_timer(instance: GameplayStatusInstance, value: float) -> void:
	var feature_storage = instance.get_feature_storage(self)
	feature_storage["timer"] = value
#endregion
