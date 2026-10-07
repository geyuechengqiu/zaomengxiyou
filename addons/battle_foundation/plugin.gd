@tool
extends EditorPlugin
#region 插件生命周期
func _enter_tree() -> void:
	if not ProjectSettings.has_setting("autoload/BattleSystem"):
		add_autoload_singleton("BattleSystem", "res://addons/battle_foundation/runtime/battle_system.gd")

func _exit_tree() -> void:
	remove_autoload_singleton("BattleSystem")
#endregion
