extends GameplayVital
class_name BattleRageVital
#region 原版入场怒气为零；运行值由GAS实例独占
func initialize(component: GameplayAttributeComponent) -> void:
	super.initialize(component)
	set_current_value(0.0)
#endregion
