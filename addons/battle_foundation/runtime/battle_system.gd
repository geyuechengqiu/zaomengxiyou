extends Node
#region 会话分配
var _session_serial: int = 0
var _prefix: String = ""
#endregion
#region 公共接口
## 用户选项使用 Core ConfigFile；定义仍来自只读 .tres 索引。
func create_session(parent: Node, manifest_path: String = "", seed_value: int = 0) -> BattleSession:
	var path := manifest_path
	if path.is_empty():
		path = ProjectSettings.get_setting("battle_foundation/manifest_path", "")
	if path.is_empty() or not is_instance_valid(parent):
		push_error("BattleSystem 需要有效 parent 和 manifest_path")
		return null
	if _prefix.is_empty():
		_prefix = "battle-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	_session_serial += 1
	var session := BattleSession.new()
	if not session.configure(StringName("%s/%d" % [_prefix, _session_serial]), path, seed_value):
		push_error(session.last_error)
		session.free()
		return null
	var configured_scale: Variant = CoreSystem.config_manager.get_value("battle", "time_scale", 1.0)
	if configured_scale is float or configured_scale is int:
		session.clock.set_time_scale(float(configured_scale))
	parent.add_child(session)
	return session
#endregion
