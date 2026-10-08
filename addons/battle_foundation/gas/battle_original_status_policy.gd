extends StatusStackingPolicy
class_name BattleOriginalStatusPolicy
#region BuffManager.replaceRule 的基础生命周期策略
## 0拒绝重复，1覆盖，2以旧nowTime与新时长比较，3独立实例，4叠层并刷新周期，5叠层保留周期，6累加时长。
@export_enum("拒绝重复:0", "覆盖:1", "原版时间比较:2", "独立实例:3", "叠层刷新周期:4", "叠层保留周期:5", "延长时间:6") var replace_rule: int = 1

func allows_parallel_instances() -> bool:
	return replace_rule == 3

func _handle_stacking(existing: GameplayStatusInstance, data: GameplayStatusData, stacks: int, _context: Dictionary) -> bool:
	match replace_rule:
		0:
			return true
		1, 2:
			if replace_rule == 2 and _original_now_time(existing) >= data.duration:
				return true
			existing.owner_component.remove_instance(existing, &"replaced")
			return false
		4, 5:
			existing.add_stack(stacks, true)
			if replace_rule == 4:
				for feature in existing.status_data.features:
					if feature is FeaturePeriodicEffects:
						feature._set_timer(existing, 0.0)
			return true
		6:
			existing.accumulate_duration(data.duration)
			existing.elapsed -= data.duration
			for feature in existing.status_data.features:
				if feature is FeaturePeriodicEffects:
					feature._set_timer(existing, feature._get_timer(existing) - data.duration)
			return true
	return true
#endregion

#region 原版nowTime在周期效果上是周期计时器，而非总存活时间
func _original_now_time(instance: GameplayStatusInstance) -> float:
	for feature in instance.status_data.features:
		if feature is FeaturePeriodicEffects and feature.period > 0.0:
			return feature._get_timer(instance)
	return instance.elapsed
#endregion
