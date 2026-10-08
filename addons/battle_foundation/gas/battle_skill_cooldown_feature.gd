extends CooldownFeature
class_name BattleSkillCooldownFeature
#region 原版按技能等级取冷却，剩余时间仍由GAS实例管理
@export var durations: Array[float] = []

func start_cooldown(ability: GameplayAbilityInstance, duration: float = -1.0) -> void:
	var level := BattleSkillLevelValues.get_level(ability.get_owner_entity(), ability.get_definition().ability_id, ability.get_blackboard_var("context", {}))
	var seconds := BattleSkillLevelValues.sample(durations, level) if duration < 0.0 else duration
	_set_timer(ability, maxf(0.0, seconds))
	_set_data(ability, "committed_duration", seconds)

func get_cooldown_progress(ability: GameplayAbilityInstance) -> float:
	var duration: float = _get_data(ability, "committed_duration", cooldown_duration)
	return get_cooldown_remaining(ability) / duration if duration > 0.0 else 0.0
#endregion
