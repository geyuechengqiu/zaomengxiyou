@tool
extends Node2D
class_name BattleMap2D
#region 连续地图模板：只保存空间与节点约定，不接管关卡战斗
@export var world_bounds := Rect2(0,0,10944,1216)
@export var ground_y: float = 1056.0

func advance_visuals(delta: float) -> void:
	for child in $Visuals.get_children():
		if child is BattleMapVisual2D: child.advance_visuals(delta)
	var gateway := get_node_or_null(^"FinalExit/Gateway") as OriginalUIAnimation2D
	if gateway != null: gateway.advance_effect(delta)

func set_final_exit_open(open: bool) -> void:
	var gateway := get_node_or_null(^"FinalExit/Gateway") as OriginalUIAnimation2D
	if gateway == null: return
	if open and not gateway.active: gateway.play_effect()
	elif not open: gateway.stop_effect()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not world_bounds.position.is_finite() or not world_bounds.size.is_finite() or world_bounds.size.x <= 0 or world_bounds.size.y <= 0 or not is_finite(ground_y):
		warnings.append("地图边界和地面高度必须是有限有效坐标。")
	for path in [^"Visuals",^"Terrain",^"SpawnPoints",^"Gates",^"Landmarks",^"PlayerBirth"]:
		if get_node_or_null(path) == null: warnings.append("连续地图模板缺少预置节点："+String(path))
	return warnings
#endregion
