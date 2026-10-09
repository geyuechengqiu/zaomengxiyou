extends BattleStatusActivationFeature
class_name BattleWushuangActivationFeature
#region 无双走现有无动作技能入口；GAS负责增益与撤销
@export var startup_armor: GameplayStatusData

func can_activate(ability: GameplayAbilityInstance, context: Dictionary) -> bool:
	var actor := ability.get_owner_entity() as BattleEntity2D
	return super.can_activate(ability, context) and actor.wushuang != null and actor.wushuang.can_activate()

func on_activate(ability: GameplayAbilityInstance, _context: Dictionary) -> void:
	var actor := ability.get_owner_entity() as BattleEntity2D
	actor.wushuang.activate(status, startup_armor)
#endregion
