@tool
extends EditorPlugin
#region 生命周期与引擎回调

func _enter_tree() -> void:
	add_autoload_singleton("GameplayAbilitySystem", "res://addons/gameplay_abiltiy_system/scripts/singletons/gameplay_ability_system.gd")
	add_autoload_singleton("DamageCalculator", "res://addons/gameplay_abiltiy_system/scripts/singletons/damage_calculator.gd")
	add_autoload_singleton("TagManager", "res://addons/gameplay_abiltiy_system/scripts/singletons/gameplay_tag_manager.gd")
	add_autoload_singleton("AbilityEventBus", "res://addons/gameplay_abiltiy_system/scripts/singletons/ability_event_bus.gd")
	add_autoload_singleton("GameplayCueManager", "res://addons/gameplay_abiltiy_system/scripts/singletons/gameplay_cue_manager.gd")

func _exit_tree() -> void:
	remove_autoload_singleton("GameplayAbilitySystem")
	remove_autoload_singleton("DamageCalculator")
	remove_autoload_singleton("TagManager")
	remove_autoload_singleton("AbilityEventBus")
	remove_autoload_singleton("GameplayCueManager")
#endregion
